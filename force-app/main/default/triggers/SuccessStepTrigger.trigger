trigger SuccessStepTrigger on Success_Steps__c (after insert, after update, after delete, after undelete) {
    new SuccessStepTriggerHandler().run();
}