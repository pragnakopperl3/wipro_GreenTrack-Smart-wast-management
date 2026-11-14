trigger GreenTrackComplaintTrigger on Waste_Complaint__c (before insert, before update, after insert, after update) {
    if (Trigger.isBefore) {
        if (Trigger.isInsert) {
            GreenTrackComplaintTriggerHandler.handleBeforeInsert(Trigger.new);
        } else if (Trigger.isUpdate) {
            GreenTrackComplaintTriggerHandler.handleBeforeUpdate(Trigger.new, Trigger.oldMap);
        }
    } else if (Trigger.isAfter) {
        if (Trigger.isInsert) {
            GreenTrackComplaintTriggerHandler.handleAfterInsert(Trigger.new);
        } else if (Trigger.isUpdate) {
            GreenTrackComplaintTriggerHandler.handleAfterUpdate(Trigger.new, Trigger.oldMap);
        }
    }
}