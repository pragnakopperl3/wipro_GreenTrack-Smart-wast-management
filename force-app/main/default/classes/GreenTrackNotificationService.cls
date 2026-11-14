public with sharing class GreenTrackNotificationService {
    private static Set<Id> resolvedNotifiedIds = new Set<Id>();

    /**
     * Sends confirmation notification to residents upon complaint creation.
     */
    public static void sendComplaintCreationNotification(List<Waste_Complaint__c> complaints) {
        if (complaints == null || complaints.isEmpty()) {
            return;
        }

        Set<Id> residentIds = new Set<Id>();
        for (Waste_Complaint__c wc : complaints) {
            if (wc.Resident__c != null) {
                residentIds.add(wc.Resident__c);
            }
        }

        if (residentIds.isEmpty()) {
            return;
        }

        Map<Id, Resident__c> residentMap = new Map<Id, Resident__c>(
            [SELECT Id, Resident_Name__c, Email__c FROM Resident__c WHERE Id IN :residentIds]
        );

        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();

        for (Waste_Complaint__c wc : complaints) {
            if (wc.Resident__c != null && residentMap.containsKey(wc.Resident__c)) {
                Resident__c res = residentMap.get(wc.Resident__c);
                if (String.isNotBlank(res.Email__c)) {
                    Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                    mail.setToAddresses(new String[] { res.Email__c });
                    mail.setSubject('GreenTrack: Complaint Logged - ' + (wc.Complaint_Type__c != null ? wc.Complaint_Type__c : 'Waste Issue'));
                    
                    String body = 'Dear ' + res.Resident_Name__c + ',\n\n' +
                                  'Thank you for reporting a waste management issue. Your complaint has been received.\n\n' +
                                  'Details:\n' +
                                  'Type: ' + wc.Complaint_Type__c + '\n' +
                                  'Location: ' + wc.Location__c + '\n' +
                                  'Severity: ' + wc.Severity__c + '\n' +
                                  'Status: ' + wc.Status__c + '\n\n' +
                                  'Our environmental sanitation team will address this promptly.\n\n' +
                                  'Regards,\nGreenTrack Waste Management Team';
                    mail.setPlainTextBody(body);
                    mail.setSaveAsActivity(false);
                    emails.add(mail);
                }
            }
        }

        if (!emails.isEmpty()) {
            try {
                Messaging.sendEmail(emails, false);
            } catch (Exception ex) {
                System.debug(LoggingLevel.WARN, 'Email notification skipped: ' + ex.getMessage());
            }
        }
    }

    /**
     * Sends resolution notification to residents when complaint status is marked Resolved.
     * Includes duplicate prevention.
     */
    public static void sendComplaintResolvedNotification(List<Waste_Complaint__c> complaints) {
        if (complaints == null || complaints.isEmpty()) {
            return;
        }

        List<Waste_Complaint__c> toNotify = new List<Waste_Complaint__c>();
        Set<Id> residentIds = new Set<Id>();

        for (Waste_Complaint__c wc : complaints) {
            if (wc.Resident__c != null && !resolvedNotifiedIds.contains(wc.Id)) {
                toNotify.add(wc);
                residentIds.add(wc.Resident__c);
                if (wc.Id != null) {
                    resolvedNotifiedIds.add(wc.Id);
                }
            }
        }

        if (toNotify.isEmpty() || residentIds.isEmpty()) {
            return;
        }

        Map<Id, Resident__c> residentMap = new Map<Id, Resident__c>(
            [SELECT Id, Resident_Name__c, Email__c FROM Resident__c WHERE Id IN :residentIds]
        );

        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();

        for (Waste_Complaint__c wc : toNotify) {
            Resident__c res = residentMap.get(wc.Resident__c);
            if (res != null && String.isNotBlank(res.Email__c)) {
                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                mail.setToAddresses(new String[] { res.Email__c });
                mail.setSubject('GreenTrack: Complaint Resolved - ' + (wc.Complaint_Type__c != null ? wc.Complaint_Type__c : 'Waste Issue'));
                
                String notes = String.isNotBlank(wc.Resolution_Notes__c) ? wc.Resolution_Notes__c : 'Cleanup completed successfully.';
                String body = 'Dear ' + res.Resident_Name__c + ',\n\n' +
                              'We are pleased to inform you that your waste management issue has been resolved.\n\n' +
                              'Complaint Type: ' + wc.Complaint_Type__c + '\n' +
                              'Location: ' + wc.Location__c + '\n' +
                              'Resolution Notes: ' + notes + '\n\n' +
                              'Thank you for helping keep our community clean and sustainable!\n\n' +
                              'Regards,\nGreenTrack Sustainability Team';
                mail.setPlainTextBody(body);
                mail.setSaveAsActivity(false);
                emails.add(mail);
            }
        }

        if (!emails.isEmpty()) {
            try {
                Messaging.sendEmail(emails, false);
            } catch (Exception ex) {
                System.debug(LoggingLevel.WARN, 'Email notification skipped: ' + ex.getMessage());
            }
        }
    }
}