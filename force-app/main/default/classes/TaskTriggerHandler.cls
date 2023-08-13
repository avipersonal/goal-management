Public with sharing class TaskTriggerHandler extends TriggerHandler {
    List<Task> taskListNew = new List<Task>();
    List<Task> taskListOld = new List<Task>();
    Map<Id, Task> taskMapOld = new Map<Id, Task>();
    final string RECORD_TYPE_DEV_NAME = 'GoalMgm_Task';

    Public TaskTriggerHandler(){
        this.taskListNew = (List<Task>) Trigger.new;
        this.taskListOld = (List<Task>) Trigger.old;
        this.taskMapOld = (Map<Id, Task>) Trigger.oldMap;
    }

    protected override void beforeInsert(){
        GoalMgm_updateASTandAETOnTaskStatusChange(this.taskListNew, this.taskMapOld);
    }

    protected override void beforeUpdate(){
        GoalMgm_updateASTandAETOnTaskStatusChange(this.taskListNew, this.taskMapOld);
    } 
    
    protected override void afterInsert(){
        GoalMgm_updateAstAetAndTaskFieldsOnSuccStep(this.taskListNew, null);
    }
    
    protected override void afterUpdate(){
        GoalMgm_updateAstAetAndTaskFieldsOnSuccStep(this.taskListNew, this.taskMapOld);
    }
    
    protected override void afterDelete(){
        GoalMgm_updateAstAetAndTaskFieldsOnSuccStep(this.taskListOld, this.taskMapOld);
    }
    
    protected override void afterUndelete(){
        GoalMgm_updateAstAetAndTaskFieldsOnSuccStep(this.taskListNew, null);
    }

    private void GoalMgm_updateASTandAETOnTaskStatusChange(List<Task> taskListNew, Map<Id, Task> taskMapOld){

        RecordType recType = [SELECT Id FROM RecordType WHERE DeveloperName = :RECORD_TYPE_DEV_NAME];

        for (Task t : taskListNew) {
            if(Trigger.isInsert){
                if(recType.Id == t.RecordTypeId) {
                    if(t.Status == 'In Progress') {
                       t.Actual_Start_Time__c = Datetime.now();
                    } else if(t.Status == 'Completed') {
                       t.Actual_Start_Time__c = Datetime.now();
                       t.Actual_End_Time__c = Datetime.now() + 0.0007;
                    }
                }
            }

            if(Trigger.isUpdate){
                if(recType.Id == t.RecordTypeId && t.Status != taskMapOld.get(t.Id).Status) {
                   if(t.Status == 'Not Started') {
                      t.Actual_Start_Time__c = null;
                      t.Actual_End_Time__c = null;
                   } else if(t.Status == 'In Progress') {
                      if(taskMapOld.get(t.Id).Status == 'Not Started'){
                           t.Actual_Start_Time__c = Datetime.now();
                       } else if(taskMapOld.get(t.Id).Status == 'Completed'){
                           t.Actual_End_Time__c = null;
                       }
                   } else if(t.Status == 'Completed') {
                       if(taskMapOld.get(t.Id).Status == 'In Progress'){
                           t.Actual_End_Time__c = Datetime.now();
                       } else if(taskMapOld.get(t.Id).Status == 'Not Started'){
                           t.Actual_Start_Time__c = Datetime.now();
                           t.Actual_End_Time__c = Datetime.now() + 0.0007;
                       }
                   }
                }
            } 
        }
   
    }
    
    private void GoalMgm_updateAstAetAndTaskFieldsOnSuccStep(List<Task> taskList, Map<Id, Task> taskMapOld){
        
        Set<Id> sucStepIds = new Set<Id>();

        Map<Id, list<string>> suStepIdToListOfStatus = new Map<Id, list<string>>();
        Map<Id, Success_steps__c> suStepIdToSuStepMap = new Map<Id, Success_steps__c>();
        List<AggregateResult> aggResultF = new List<AggregateResult>();
        
        List<Success_Steps__c> suStepList = new List<Success_Steps__c>();
            
        sucStepIds = getSuccessStepIds(taskList, taskMapOld);
        
        if(sucStepIds.size() > 0){
           
            List<AggregateResult> aggResults = [SELECT COUNT(Id) tTasks, MAX(Actual_End_Time__c) yaet, MIN(Actual_Start_Time__c) oast, Success_Step__c ss, Status FROM Task WHERE Success_Step__c IN :sucStepIds AND RecordType.DeveloperName = :RECORD_TYPE_DEV_NAME GROUP BY ROLLUP(Success_Step__c, Status)];
            For(AggregateResult ar : aggResults) {
                string tStatus = (string) ar.get('Status');
                Id suStepId = (Id) ar.get('ss');
                
                if(tStatus == null && suStepId != null) {
                    Success_Steps__c s = new Success_Steps__c(Id = suStepId);
                    s.Number_Of_Tasks__c = (integer) ar.get('tTasks');
                    suStepIdToSuStepMap.put(suStepId, s);
                } 
                
                if(tStatus != null) {
                   if(suStepIdToListOfStatus.containsKey(suStepId)){
                     suStepIdToListOfStatus.get(suStepId).add(tStatus);
                   } else {
                     System.debug('List status');
                     List<string> temList = new List<string>{tStatus};
                     suStepIdToListOfStatus.put(suStepId, temList);
                   }
                   aggResultF.add(ar);
                }
                              
            }
            
            For(AggregateResult ar : aggResultF) {
                string tStatus = (string) ar.get('Status');
                Id suStepId = (Id) ar.get('ss');
                
                if(tStatus != null && suStepIdToListOfStatus.containsKey(suStepId) && suStepIdToListOfStatus.get(suStepId).size() == 2 && suStepIdToListOfStatus.get(suStepId).contains('Not Started') 
                   && suStepIdToListOfStatus.get(suStepId).contains('In Progress')){
                    if(tStatus == 'In Progress') {
                       Success_steps__c s = suStepIdToSuStepMap.get(suStepId);
                       s.Actual_End_Date__c = null;
                        
                       datetime temp = (datetime) ar.get('oast');
                       s.Actual_End_Date__c = temp?.date();
                        
                       s.Is_Completed__c = false;
                       s.Task_Remaining__c = (integer) ar.get('tTasks');
                    }  
                } 
                
                if(tStatus != null && suStepIdToListOfStatus.containsKey(suStepId) && suStepIdToListOfStatus.get(suStepId).size() == 2 && suStepIdToListOfStatus.get(suStepId).contains('Not Started') 
                    && suStepIdToListOfStatus.get(suStepId).contains('Completed')) {
                        
                    Success_steps__c s = suStepIdToSuStepMap.get(suStepId);
                    if(tStatus == 'Completed'){
                       s.Actual_End_Date__c = null;
                        
                       datetime temp = (datetime) ar.get('oast');
                       s.Actual_Start_Date__c = temp?.date();
                        
                       s.Is_Completed__c = false;
                    }
                    if(tStatus == 'Not Started'){
                       s.Task_Remaining__c = (integer) ar.get('tTasks');       
                    }    
                }
                
                if(tStatus != null && suStepIdToListOfStatus.containsKey(suStepId) && suStepIdToListOfStatus.get(suStepId).contains('Completed') 
                    && suStepIdToListOfStatus.get(suStepId).contains('In Progress')) {
                    Success_steps__c s = suStepIdToSuStepMap.get(suStepId);
                    integer taskRem = (s.Task_Remaining__c)?.intValue();
                    integer totTasks = (integer) ar.get('tTasks');
                        
                    if(tStatus == 'In Progress' || tStatus == 'Completed'){              
                      if(tStatus == 'In Progress') {
                        taskRem = taskRem == null ? totTasks : taskRem + totTasks;     
                      }
                        
                      datetime temp = (datetime) ar.get('oast');
                        
                      if(s.Actual_Start_Date__c == null || (s.Actual_Start_Date__c > temp)) {
                         s.Actual_Start_Date__c = temp?.date();
                      } 
                        
                      s.Actual_End_Date__c = null;
                      s.Is_Completed__c = false;
                    }
                  
                   if(tStatus == 'Not Started'){
                      taskRem = taskRem == null ? totTasks : taskRem + totTasks;
                   }
                   s.Task_Remaining__c = taskRem;
                }
                
                if(tStatus != null && suStepIdToListOfStatus.containsKey(suStepId) && suStepIdToListOfStatus.get(suStepId).size() == 1 && suStepIdToListOfStatus.get(suStepId).contains('In Progress')) {
                    Success_steps__c s = suStepIdToSuStepMap.get(suStepId);
                    s.Actual_End_Date__c = null;
                    
                    datetime temp = (datetime) ar.get('oast');
                    s.Actual_Start_Date__c = temp?.date();
                    
                    s.Is_Completed__c = false;
                    s.Task_Remaining__c = (integer) ar.get('tTasks');
                }
                
                if(tStatus != null && suStepIdToListOfStatus.containsKey(suStepId) && suStepIdToListOfStatus.get(suStepId).size() == 1 && suStepIdToListOfStatus.get(suStepId).contains('Completed')) {
                    Success_steps__c s = suStepIdToSuStepMap.get(suStepId);
                    
                    datetime tempEn = (datetime) ar.get('yaet');
                    datetime tempSt = (datetime) ar.get('oast');
                    
                    s.Actual_End_Date__c = tempEn?.date();
                    s.Actual_Start_Date__c = tempSt?.date();
                    s.Task_Remaining__c = 0;
                    s.Is_Completed__c = true;
                }
            }
      
            For(Id sI : sucStepIds) {
                if(suStepIdToSuStepMap.containskey(sI)) {
                   suStepList.add(suStepIdToSuStepMap.get(sI));
                } else {
                   Success_steps__c s = new Success_steps__c(Id=sI);
                   s.Actual_End_Date__c = null;
                   s.Actual_Start_Date__c = null;
                   s.Is_Completed__c = false;
                   s.Number_of_Tasks__c = 0;
                   s.Task_Remaining__c = 0;
                   suStepList.add(s);
                }
            }
         
            if(suStepList.size() > 0) {
                update suStepList;
            }
        }     
    }
    
    private Set<Id> getSuccessStepIds(List<Task> taskList, Map<Id, Task> taskMapOld) {
        Set<Id> sStepIds = new Set<Id>();
        
        For(Task t : taskList) {
            if(Trigger.isInsert || Trigger.isDelete || Trigger.isUndelete){
                if(t.Success_Step__c != null){
                    sStepIds.add(t.Success_Step__c);
                }
            }
            
            if(Trigger.isUpdate){
                Id oldStId = taskMapOld.get(t.Id).Success_Step__c;
                if(t.Success_Step__c != null && t.Status != taskMapOld.get(t.Id).Status) {
                    sStepIds.add(t.Success_Step__c);
                } 
                if(t.Success_Step__c != oldStId){
                    if(t.Success_Step__c != null) {
                        sStepIds.add(t.Success_Step__c);
                    }
                    if(oldStId != null){
                        sStepIds.add(oldStId);
                    }
                }
            }
        }
        
        return sStepIds;
    }
}