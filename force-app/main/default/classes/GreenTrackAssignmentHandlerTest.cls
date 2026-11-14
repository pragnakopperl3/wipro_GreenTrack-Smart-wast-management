@isTest
private class GreenTrackAssignmentHandlerTest {

    @testSetup
    static void setupTestData() {
        Resident__c res = new Resident__c(
            Resident_Name__c = 'Bob Builder',
            Email__c = 'bob@example.com',
            Location__c = 'Central City'
        );
        insert res;

        List<Service_Team__c> teams = new List<Service_Team__c>{
            new Service_Team__c(Name = 'Central Team A', Team_Name__c = 'Central Team A', Location__c = 'Central City', Team_Status__c = 'Available', Total_Assignments__c = 0),
            new Service_Team__c(Name = 'Central Team B', Team_Name__c = 'Central Team B', Location__c = 'Central City', Team_Status__c = 'Available', Total_Assignments__c = 5),
            new Service_Team__c(Name = 'Busy South Team', Team_Name__c = 'Busy South Team', Location__c = 'South District', Team_Status__c = 'Busy', Total_Assignments__c = 2)
        };
        insert teams;
    }

    @isTest
    static void testAssignServiceTeams() {
        Resident__c res = [SELECT Id FROM Resident__c LIMIT 1];

        Waste_Complaint__c comp = new Waste_Complaint__c(
            Resident__c = res.Id,
            Complaint_Type__c = 'Illegal Dumping',
            Location__c = 'Central City',
            Severity__c = 'High',
            Status__c = 'New'
        );

        Test.startTest();
        insert comp;
        Test.stopTest();

        Waste_Complaint__c queried = [SELECT Id, Assigned_Team__c, Status__c FROM Waste_Complaint__c WHERE Id = :comp.Id];
        Service_Team__c expectedTeam = [SELECT Id FROM Service_Team__c WHERE Name = 'Central Team A' LIMIT 1];

        System.assertEquals(expectedTeam.Id, queried.Assigned_Team__c, 'Should be assigned to team with lowest workload');
        System.assertEquals('Assigned', queried.Status__c, 'Status should update to Assigned');

        // Test null/empty guards
        GreenTrackAssignmentHandler.assignServiceTeams(null);
        GreenTrackAssignmentHandler.assignServiceTeams(new List<Waste_Complaint__c>());
        GreenTrackAssignmentHandler.updateTeamAssignmentCounts(null);
        GreenTrackAssignmentHandler.updateTeamAssignmentCounts(new Set<Id>());
    }

    @isTest
    static void testNoAvailableTeamScenario() {
        Resident__c res = [SELECT Id FROM Resident__c LIMIT 1];

        // Critical complaint in an unserviced district
        Waste_Complaint__c comp = new Waste_Complaint__c(
            Resident__c = res.Id,
            Complaint_Type__c = 'Hazardous Waste',
            Location__c = 'West District',
            Severity__c = 'Critical',
            Status__c = 'New'
        );

        Test.startTest();
        insert comp;
        Test.stopTest();

        Waste_Complaint__c queried = [SELECT Id, Assigned_Team__c, Status__c FROM Waste_Complaint__c WHERE Id = :comp.Id];
        System.assertEquals(null, queried.Assigned_Team__c, 'No team available in West District');
        System.assertEquals('Escalated', queried.Status__c, 'Critical complaint with no team should escalate');
    }

    @isTest
    static void testUpdateTeamAssignmentCounts() {
        Service_Team__c team = [SELECT Id FROM Service_Team__c WHERE Name = 'Central Team A' LIMIT 1];
        Resident__c res = [SELECT Id FROM Resident__c LIMIT 1];

        List<Waste_Complaint__c> complaints = new List<Waste_Complaint__c>{
            new Waste_Complaint__c(Resident__c = res.Id, Complaint_Type__c = 'Street Litter', Location__c = 'Central City', Severity__c = 'Low', Status__c = 'In Progress', Assigned_Team__c = team.Id),
            new Waste_Complaint__c(Resident__c = res.Id, Complaint_Type__c = 'Overflowing Bin', Location__c = 'Central City', Severity__c = 'Medium', Status__c = 'Assigned', Assigned_Team__c = team.Id)
        };
        insert complaints;

        Test.startTest();
        GreenTrackAssignmentHandler.updateTeamAssignmentCounts(new Set<Id>{ team.Id });
        Test.stopTest();

        Service_Team__c updatedTeam = [SELECT Total_Assignments__c FROM Service_Team__c WHERE Id = :team.Id];
        System.assert(updatedTeam.Total_Assignments__c >= 2, 'Total assignments should reflect active complaints');
    }
}