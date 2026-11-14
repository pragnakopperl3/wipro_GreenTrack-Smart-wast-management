@isTest
private class GreenTrackComplaintServiceTest {

    @testSetup
    static void setupTestData() {
        Resident__c res = new Resident__c(
            Resident_Name__c = 'Alice Green',
            Email__c = 'alice@example.com',
            Phone__c = '9876543210',
            Location__c = 'North District',
            Resident_Type__c = 'Residential'
        );
        insert res;

        Service_Team__c team = new Service_Team__c(
            Name = 'Alpha Sanitation Crew',
            Team_Name__c = 'Alpha Sanitation Crew',
            Location__c = 'North District',
            Team_Status__c = 'Available',
            Total_Assignments__c = 0
        );
        insert team;

        Waste_Complaint__c comp = new Waste_Complaint__c(
            Resident__c = res.Id,
            Complaint_Type__c = 'Overflowing Bin',
            Location__c = 'North District',
            Severity__c = 'High',
            Status__c = 'New',
            Reported_Date__c = System.now(),
            Due_Date__c = Date.today().addDays(-1)
        );
        insert comp;
    }

    @isTest
    static void testSlaCalculations() {
        Test.startTest();
        System.assertEquals(4, GreenTrackComplaintService.getSlaHours('Critical'), 'Critical should be 4h');
        System.assertEquals(12, GreenTrackComplaintService.getSlaHours('High'), 'High should be 12h');
        System.assertEquals(24, GreenTrackComplaintService.getSlaHours('Medium'), 'Medium should be 24h');
        System.assertEquals(48, GreenTrackComplaintService.getSlaHours('Low'), 'Low should be 48h');
        System.assertEquals(24, GreenTrackComplaintService.getSlaHours(null), 'Null severity should default to 24h');
        System.assertEquals(24, GreenTrackComplaintService.getSlaHours('Unknown'), 'Unknown severity should default to 24h');

        Date calculatedDate = GreenTrackComplaintService.calculateDueDate(System.now(), 24);
        System.assertNotEquals(null, calculatedDate, 'Calculated due date should not be null');
        Test.stopTest();
    }

    @isTest
    static void testResolveComplaint() {
        Waste_Complaint__c comp = [SELECT Id FROM Waste_Complaint__c LIMIT 1];

        Test.startTest();
        Waste_Complaint__c resolved = GreenTrackComplaintService.resolveComplaint(comp.Id, 'Waste bin cleared and disinfected.');
        Test.stopTest();

        System.assertEquals('Resolved', resolved.Status__c, 'Status should be Resolved');
        System.assertNotEquals(null, resolved.Resolution_Date__c, 'Resolution date must be populated');
        System.assertEquals('Waste bin cleared and disinfected.', resolved.Resolution_Notes__c, 'Notes should match');

        // Test null id exception
        try {
            GreenTrackComplaintService.resolveComplaint(null, 'Test');
            System.assert(false, 'Exception expected for null ID');
        } catch (IllegalArgumentException e) {
            System.assert(e.getMessage().contains('cannot be null'), 'Expected error message');
        }
    }

    @isTest
    static void testGetStatisticsAndOverdue() {
        Test.startTest();
        Map<String, Object> stats = GreenTrackComplaintService.getComplaintStatistics();
        List<Waste_Complaint__c> overdueList = GreenTrackComplaintService.getOverdueComplaints();
        Test.stopTest();

        System.assertNotEquals(null, stats, 'Stats map should not be null');
        System.assertEquals(1, stats.get('totalComplaints'), 'Should have 1 total complaint');
        System.assertEquals(1, stats.get('openComplaints'), 'Should have 1 open complaint');
        System.assert(overdueList.size() >= 1, 'Should find at least 1 overdue complaint');
    }
}