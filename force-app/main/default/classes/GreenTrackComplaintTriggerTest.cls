@isTest
private class GreenTrackComplaintTriggerTest {

    @testSetup
    static void setupTestData() {
        Resident__c res = new Resident__c(
            Resident_Name__c = 'Dana Rivers',
            Email__c = 'dana@example.com',
            Location__c = 'South District'
        );
        insert res;

        Service_Team__c team = new Service_Team__c(
            Name = 'South Quick Cleaners',
            Team_Name__c = 'South Quick Cleaners',
            Location__c = 'South District',
            Team_Status__c = 'Available',
            Total_Assignments__c = 0
        );
        insert team;
    }

    @isTest
    static void testTriggerLifecycle() {
        Resident__c res = [SELECT Id FROM Resident__c LIMIT 1];
        Service_Team__c team = [SELECT Id FROM Service_Team__c LIMIT 1];

        Waste_Complaint__c comp = new Waste_Complaint__c(
            Resident__c = res.Id,
            Complaint_Type__c = 'Street Litter',
            Location__c = 'South District',
            Severity__c = 'Medium',
            Status__c = 'New'
        );

        Test.startTest();
        insert comp;

        // Verify SLA and Auto assignment
        Waste_Complaint__c inserted = [SELECT Id, SLA_Target_Hours__c, Due_Date__c, Assigned_Team__c, Status__c FROM Waste_Complaint__c WHERE Id = :comp.Id];
        System.assertEquals(24, inserted.SLA_Target_Hours__c, 'Medium severity SLA should be 24h');
        System.assertEquals(team.Id, inserted.Assigned_Team__c, 'Should be assigned to South team');

        // Update Severity to Critical
        inserted.Severity__c = 'Critical';
        update inserted;

        Waste_Complaint__c updated = [SELECT Id, SLA_Target_Hours__c FROM Waste_Complaint__c WHERE Id = :comp.Id];
        System.assertEquals(4, updated.SLA_Target_Hours__c, 'Critical severity SLA should be 4h');

        // Resolve complaint
        updated.Status__c = 'Resolved';
        updated.Resolution_Notes__c = 'All street litter cleared.';
        update updated;

        Waste_Complaint__c resolved = [SELECT Id, Status__c, Resolution_Date__c FROM Waste_Complaint__c WHERE Id = :comp.Id];
        System.assertEquals('Resolved', resolved.Status__c, 'Status should be Resolved');
        System.assertNotEquals(null, resolved.Resolution_Date__c, 'Resolution date must be stamped');
        Test.stopTest();
    }

    @isTest
    static void testBulkComplaints() {
        Resident__c res = [SELECT Id FROM Resident__c LIMIT 1];
        List<Waste_Complaint__c> bulkList = new List<Waste_Complaint__c>();

        for (Integer i = 0; i < 50; i++) {
            bulkList.add(new Waste_Complaint__c(
                Resident__c = res.Id,
                Complaint_Type__c = 'Missed Collection',
                Location__c = 'South District',
                Severity__c = Math.mod(i, 2) == 0 ? 'Low' : 'High',
                Status__c = 'New'
            ));
        }

        Test.startTest();
        insert bulkList;
        Test.stopTest();

        List<Waste_Complaint__c> results = [SELECT Id, Assigned_Team__c FROM Waste_Complaint__c WHERE Id IN :bulkList];
        System.assertEquals(50, results.size(), 'All 50 bulk complaints should be inserted');
    }
}