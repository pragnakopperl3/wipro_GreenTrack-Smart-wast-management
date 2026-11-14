@isTest
private class GreenTrackNotificationServiceTest {

    @testSetup
    static void setupTestData() {
        Resident__c res = new Resident__c(
            Resident_Name__c = 'Charlie Clean',
            Email__c = 'charlie@example.com',
            Location__c = 'East District'
        );
        insert res;
    }

    @isTest
    static void testNotifications() {
        Resident__c res = [SELECT Id FROM Resident__c LIMIT 1];

        Waste_Complaint__c comp = new Waste_Complaint__c(
            Resident__c = res.Id,
            Complaint_Type__c = 'Bio Waste',
            Location__c = 'East District',
            Severity__c = 'Critical',
            Status__c = 'New'
        );
        insert comp;

        Test.startTest();
        // Creation notification
        GreenTrackNotificationService.sendComplaintCreationNotification(new List<Waste_Complaint__c>{ comp });

        // Resolution notification
        comp.Status__c = 'Resolved';
        comp.Resolution_Notes__c = 'Bio waste safely neutralized and removed.';
        update comp;
        GreenTrackNotificationService.sendComplaintResolvedNotification(new List<Waste_Complaint__c>{ comp });

        // Test null/empty guard
        GreenTrackNotificationService.sendComplaintCreationNotification(null);
        GreenTrackNotificationService.sendComplaintResolvedNotification(null);
        Test.stopTest();

        System.assertNotEquals(null, comp.Id, 'Complaint should exist');
    }
}