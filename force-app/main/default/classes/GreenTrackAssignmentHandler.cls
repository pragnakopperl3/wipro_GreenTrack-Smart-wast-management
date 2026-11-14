public with sharing class GreenTrackAssignmentHandler {
    public static Boolean isUpdatingCounts = false;

    /**
     * Automatically matches and assigns available service teams based on location and lowest workload.
     */
    public static void assignServiceTeams(List<Waste_Complaint__c> complaints) {
        if (complaints == null || complaints.isEmpty()) {
            return;
        }

        Set<String> locations = new Set<String>();
        for (Waste_Complaint__c wc : complaints) {
            if (wc.Assigned_Team__c == null && String.isNotBlank(wc.Location__c)) {
                locations.add(wc.Location__c);
            }
        }

        if (locations.isEmpty()) {
            return;
        }

        // Query available teams in relevant locations ordered by lowest workload
        List<Service_Team__c> availableTeams = [
            SELECT Id, Name, Location__c, Team_Status__c, Total_Assignments__c
            FROM Service_Team__c
            WHERE Team_Status__c = 'Available'
              AND Location__c IN :locations
            ORDER BY Total_Assignments__c ASC, Name ASC
        ];

        // Map teams by location
        Map<String, List<Service_Team__c>> teamsByLocation = new Map<String, List<Service_Team__c>>();
        for (Service_Team__c team : availableTeams) {
            if (!teamsByLocation.containsKey(team.Location__c)) {
                teamsByLocation.put(team.Location__c, new List<Service_Team__c>());
            }
            teamsByLocation.get(team.Location__c).add(team);
        }

        // Assign teams
        for (Waste_Complaint__c wc : complaints) {
            if (wc.Assigned_Team__c == null && String.isNotBlank(wc.Location__c)) {
                List<Service_Team__c> locTeams = teamsByLocation.get(wc.Location__c);
                if (locTeams != null && !locTeams.isEmpty()) {
                    // Pick the team with the least assignments
                    Service_Team__c bestTeam = locTeams[0];
                    wc.Assigned_Team__c = bestTeam.Id;
                    if (wc.Status__c == 'New' || String.isBlank(wc.Status__c)) {
                        wc.Status__c = 'Assigned';
                    }
                    // Increment in-memory counter to balance multiple assignments in the same transaction
                    bestTeam.Total_Assignments__c = (bestTeam.Total_Assignments__c == null ? 0 : bestTeam.Total_Assignments__c) + 1;
                    // Re-sort list to maintain lowest load first
                    locTeams.sort();
                } else {
                    // If no team is available in the location, mark for Escalation / Urgent if high severity
                    if (wc.Severity__c == 'Critical') {
                        wc.Status__c = 'Escalated';
                    }
                }
            }
        }
    }

    /**
     * Recalculates Total_Assignments__c on Service Teams using SOQL Aggregate Queries.
     * Protected with recursion guard.
     */
    public static void updateTeamAssignmentCounts(Set<Id> teamIds) {
        if (teamIds == null || teamIds.isEmpty() || isUpdatingCounts) {
            return;
        }

        isUpdatingCounts = true;
        try {
            // Aggregate query to count active assignments per team
            Map<Id, Integer> countMap = new Map<Id, Integer>();
            for (Id tId : teamIds) {
                countMap.put(tId, 0);
            }

            List<AggregateResult> results = [
                SELECT Assigned_Team__c teamId, COUNT(Id) totalCount
                FROM Waste_Complaint__c
                WHERE Assigned_Team__c IN :teamIds
                  AND Status__c NOT IN ('Resolved', 'Closed')
                GROUP BY Assigned_Team__c
            ];

            for (AggregateResult ar : results) {
                Id tId = (Id) ar.get('teamId');
                Integer countVal = ((Decimal) ar.get('totalCount')).intValue();
                countMap.put(tId, countVal);
            }

            List<Service_Team__c> teamsToUpdate = new List<Service_Team__c>();
            for (Id tId : countMap.keySet()) {
                teamsToUpdate.add(new Service_Team__c(
                    Id = tId,
                    Total_Assignments__c = countMap.get(tId)
                ));
            }

            if (!teamsToUpdate.isEmpty()) {
                update teamsToUpdate;
            }
        } finally {
            isUpdatingCounts = false;
        }
    }
}