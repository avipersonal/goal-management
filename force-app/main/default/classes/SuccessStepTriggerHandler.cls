/**
 * @description       : 
 * @author            : Avi Jain
 * @group             : 
 * @last modified on  : 07-14-2023
 * @last modified by  : Avi Jain
**/
public class SuccessStepTriggerHandler extends TriggerHandler {
    List<Success_steps__c> successStepsListNew = new List<Success_steps__c>();
    List<Success_steps__c> successStepsListOld = new List<Success_steps__c>();
    Map<Id, Success_steps__c> successStepsMapOld = new Map<Id, Success_steps__c>();
    
    {
        successStepsListNew = (List<Success_steps__c>) Trigger.new;
        successStepsListOld = (List<Success_steps__c>) Trigger.old;
        successStepsMapOld = (Map<Id, Success_steps__c>) Trigger.oldMap;
    }
    
    protected override void afterinsert(){
        updateGoalAetAstComTaskFieldsOnSucStepChange(successStepsListNew, null);
    }
    
    protected override void afterupdate(){
        updateGoalAetAstComTaskFieldsOnSucStepChange(successStepsListNew, successStepsMapOld);
    }
    
    protected override void afterdelete(){
        updateGoalAetAstComTaskFieldsOnSucStepChange(successStepsListOld, null);
    }
    
    protected override void afterundelete(){
        updateGoalAetAstComTaskFieldsOnSucStepChange(successStepsListNew, null);
    }
    
    private void updateGoalAetAstComTaskFieldsOnSucStepChange(List<Success_steps__c> suStepList, Map<Id, Success_steps__c> suStepsMapOld) {
        
      List<Goals__c> goalListToUpd = new List<Goals__c>();
      Map<Id, Goals__c> goalIdToGoalMap = new Map<Id, Goals__c>();
      Map<Id, list<boolean>> goalIdToComStatusMap = new Map<Id, list<boolean>>();
      List<AggregateResult> aggResultFil = new List<AggregateResult>();
      
      Set<Id> goalIds = getGoalIds(suStepList, suStepsMapOld);
        
      if(goalIds.size() > 0){
         List<AggregateResult> aggResults = [SELECT COUNT(Id) tSuSteps, MAX(Actual_End_Date__c) yaet, MIN(Actual_Start_Date__c) oast, Goal__c, Is_Completed__c FROM Success_Steps__c WHERE Goal__c IN :goalIds GROUP BY ROLLUP(Goal__c, Is_Completed__c)];
          
          for(AggregateResult ag : aggResults) {
             Id goalId = (Id) ag.get('Goal__c');
             boolean isComplete = (boolean) ag.get('Is_Completed__c');
              
             if(isComplete == null && goalId != null) {
                Goals__c g = new Goals__c(Id= goalId);
                g.Total_Steps__c = (decimal) ag.get('tSuSteps');
                goalIdToGoalMap.put(goalId, g);
             }
              
             if(isComplete != null){
                 if(goalIdToComStatusMap.containsKey(goalId)) {
                    goalIdToComStatusMap.get(goalId).add(isComplete); 
                 } else {
                    List<boolean> complStatus = new List<boolean>{isComplete};
                    goalIdToComStatusMap.put(goalId, complStatus);
                 }
                 aggResultFil.add(ag);
             }
          }
          
          For(AggregateResult ag: aggResultFil) {
             Id goalId = (Id) ag.get('Goal__c');
             boolean isComplete = (boolean) ag.get('Is_Completed__c');
              
             if(goalIdToComStatusMap.containsKey(goalId) && goalIdToComStatusMap.get(goalId).size() == 2){
                Goals__c g = goalIdToGoalMap.get(goalId);
                
                if(isComplete == false){
                   g.Steps_Remaining__c = (integer) ag.get('tSuSteps');
                }
                 
                if(g.Actual_Start_Date__c == null || (g.Actual_Start_Date__c != null && g.Actual_Start_Date__c > (date) ag.get('oast'))) {
                   g.Actual_Start_Date__c = (date) ag.get('oast');     
                } 
                 
                g.Actual_End_Date__c = null;
                g.Is_Completed__c = false;
             }
              
              if(goalIdToComStatusMap.containsKey(goalId) && goalIdToComStatusMap.get(goalId).size() == 1) {
                Goals__c g = goalIdToGoalMap.get(goalId);
                g.Actual_End_Date__c = (date) ag.get('yaet');
                g.Actual_Start_Date__c = (date) ag.get('oast');
                
                if(isComplete == true) {
                  g.Is_Completed__c = true; 
                  g.Steps_Remaining__c = 0;
                } else {
                  g.Is_Completed__c = false;
                  g.Steps_Remaining__c = (integer) ag.get('tSuSteps');
                }
              } 
          }
          
          if(goalIdToGoalMap.size() > 0){
              update goalIdToGoalMap.values();
          }
          
      }  
    }
    
    private Set<Id> getGoalIds(List<Success_steps__c> suSteps, Map<Id, Success_steps__c> suStepsOldMap) {
        Set<Id> goalIds = new Set<Id>();
        
        for(Success_Steps__c ss : suSteps) {
            if(Trigger.isInsert || Trigger.isDelete || Trigger.isUndelete) {
                if(ss.Goal__c != null && (ss.Number_of_Tasks__c != null || ss.Actual_Start_Date__c != null ||
                 ss.Actual_End_Date__c != null || ss.Is_Completed__c != null)) {
                   goalIds.add(ss.Goal__c);
                } 
            } else if(Trigger.isUpdate) {
                Id goalIdOld = suStepsOldMap.get(ss.Id).Goal__c;
                boolean isAnyOfItChanged = (ss.Number_of_Tasks__c != suStepsOldMap.get(ss.Id).Number_Of_Tasks__c) ||
                                           (ss.Actual_Start_Date__c != suStepsOldMap.get(ss.Id).Actual_Start_Date__c) ||
                                           (ss.Actual_End_Date__c != suStepsOldMap.get(ss.Id).Actual_End_Date__c) || 
                                           (ss.Is_Completed__c != suStepsOldMap.get(ss.Id).Is_Completed__c);
                
                if(ss.Goal__c != null && isAnyOfItChanged) {
                   goalIds.add(ss.Goal__c);                              
                } 
                if(ss.Goal__c != goalIdOld) {
                   if(ss.Goal__c != null) {
                      goalIds.add(ss.Goal__c);                       
                   }
                   if(goalIdOld != null) {
                      goalIds.add(goalIdOld);     
                   }
                }
            }
        }
        
        return goalIds;
    }
}