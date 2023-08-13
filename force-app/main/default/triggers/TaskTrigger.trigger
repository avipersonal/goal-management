trigger TaskTrigger on Task (before insert, before update, after insert, after update, after delete, after undelete) {
    new TaskTriggerHandler().run();
}