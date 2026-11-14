public with sharing class GreenTrackComplaintTriggerHandler {
    private static Boolean hasRunAfterInsert = false;
    private static Boolean hasRunAfterUpdate = false;

    public static void handleBeforeInsert(List<Waste_Complaint__c> newComplaints) {
        for (Waste_Complaint__c wc : newComplaints) {
            // Set reported date if null
            if (wc.Reported_Date__c == null) {
                wc.Reported_Date__c = System.now();
            }

            // Set SLA target hours & due date
            Integer slaHours = GreenTrackComplaintService.getSlaHours(wc.Severity__c);
            wc.SLA_Target_Hours__c = slaHours;
            if (wc.Due_Date__c == null) {
                wc.Due_Date__c = GreenTrackComplaintService.calculateDueDate(wc.Reported_Date__c, slaHours);
            }
        }

        // Automatic team assignment based on location and availability
        GreenTrackAssignmentHandler.assignServiceTeams(newComplaints);
    }

    public static void handleBeforeUpdate(List<Waste_Complaint__c> newComplaints, Map<Id, Waste_Complaint__c> oldMap) {
        for (Waste_Complaint__c wc : newComplaints) {
            Waste_Complaint__c oldWc = oldMap.get(wc.Id);

            // Severity changed: recalculate SLA target and Due Date
            if (wc.Severity__c != oldWc.Severity__c) {
                Integer slaHours = GreenTrackComplaintService.getSlaHours(wc.Severity__c);
                wc.SLA_Target_Hours__c = slaHours;
                if (wc.Reported_Date__c != null) {
                    wc.Due_Date__c = GreenTrackComplaintService.calculateDueDate(wc.Reported_Date__c, slaHours);
                }
            }

            // Status changed to Resolved: stamp Resolution Date
            if (wc.Status__c == 'Resolved' && oldWc.Status__c != 'Resolved') {
                if (wc.Resolution_Date__c == null) {
                    wc.Resolution_Date__c = System.now();
                }
            }

            // Team assigned manually or updated
            if (wc.Assigned_Team__c != null && oldWc.Assigned_Team__c == null && wc.Status__c == 'New') {
                wc.Status__c = 'Assigned';
            }
        }
    }

    public static void handleAfterInsert(List<Waste_Complaint__c> newComplaints) {
        if (hasRunAfterInsert) {
            return;
        }
        hasRunAfterInsert = true;

        Set<Id> teamIds = new Set<Id>();
        for (Waste_Complaint__c wc : newComplaints) {
            if (wc.Assigned_Team__c != null) {
                teamIds.add(wc.Assigned_Team__c);
            }
        }

        // Update team workload
        if (!teamIds.isEmpty()) {
            GreenTrackAssignmentHandler.updateTeamAssignmentCounts(teamIds);
        }

        // Send confirmation notification
        GreenTrackNotificationService.sendComplaintCreationNotification(newComplaints);
    }

    public static void handleAfterUpdate(List<Waste_Complaint__c> newComplaints, Map<Id, Waste_Complaint__c> oldMap) {
        Set<Id> teamIdsToUpdate = new Set<Id>();
        List<Waste_Complaint__c> resolvedComplaints = new List<Waste_Complaint__c>();

        for (Waste_Complaint__c wc : newComplaints) {
            Waste_Complaint__c oldWc = oldMap.get(wc.Id);

            // Track team changes
            if (wc.Assigned_Team__c != oldWc.Assigned_Team__c) {
                if (wc.Assigned_Team__c != null) teamIdsToUpdate.add(wc.Assigned_Team__c);
                if (oldWc.Assigned_Team__c != null) teamIdsToUpdate.add(oldWc.Assigned_Team__c);
            }

            // Track status changes to/from resolved/closed for workload
            if (wc.Status__c != oldWc.Status__c && wc.Assigned_Team__c != null) {
                teamIdsToUpdate.add(wc.Assigned_Team__c);
            }

            // Resolution notification
            if (wc.Status__c == 'Resolved' && oldWc.Status__c != 'Resolved') {
                resolvedComplaints.add(wc);
            }
        }

        if (!teamIdsToUpdate.isEmpty()) {
            GreenTrackAssignmentHandler.updateTeamAssignmentCounts(teamIdsToUpdate);
        }

        if (!resolvedComplaints.isEmpty()) {
            GreenTrackNotificationService.sendComplaintResolvedNotification(resolvedComplaints);
        }
    }
}