/**
* @module            : Real_Estate_Module
* @description       : Creates KYC records dynamically based on CMDT configuration
* @namespace         :
* @author            : SHUBHAM GUPTA
* @group             : DYNAMIC KYC CONTROL FRAMEWORK
* @testClass		  : 
* @last modified on  : 
* @last modified by  : 
**/
public without sharing class KYCCreationService implements TriggerAction.AfterInsert, TriggerAction.AfterUpdate {
    
    // ============= AFTER INSERT =======================
    public void afterInsert(List<sObject> records){
        
        System.debug('Entered afterInsert ' + records.size());
        createKYCIfConfigured(records, new Map<Id, sObject>{}, 'After Insert');
    }
    
    // =============== AFTER UPDATE ==========================
    public void afterUpdate(List<sObject> newRecords, List<sObject> oldRecords){
        
        // Map old records by Id for quick comparison
        Map<Id, sObject> oldRecordsMap = new Map<Id, sObject>(); 
        
        for (sObject oldRec : oldRecords) {
            oldRecordsMap.put(oldRec.Id, oldRec);
        }
        
        System.debug('Entered afterUpdate ' + newRecords.size() + ' ' + oldRecords.size());
        createKYCIfConfigured(newRecords, oldRecordsMap, 'After Update');
    }
    
    //Dynamically creates KYC records based on active CMDT configuration.
    //If trigger conditions match, a KYC record is created and scheduled for expiration.
    public static void createKYCIfConfigured(List<sObject> newRecords, Map<Id, sObject> oldRecords, String triggerContext) {
        
        if (newRecords == null || newRecords.isEmpty()) 
            return;
        
        String objectName = newRecords[0].getSObjectType().getDescribe().getName();
        
        // Fetch all KYC creation configurations from Custom Metadata
        MAP<Id, KYC_Creation_Config__mdt> configs = new MAP<Id, KYC_Creation_Config__mdt>([SELECT Id, Source_Object__c, Trigger_Event__c, Is_Active__c,
                                                                                           Validity_Period_in_Months__c, Filter_Logic__c, Is_Lead_Or_Contact__c,
                                                                                           Linked_Field_API_Name__c FROM KYC_Creation_Config__mdt
                                                                                           Where Source_Object__c =:objectName and Is_Active__c = true 
                                                                                           and Trigger_Event__c =: triggerContext]);
        
        List<KYC_Conditions_Config__mdt> conditions = [SELECT Id, KYC_Creation_Config__c, Sequence_Number__c, Field_API_Name__c, Operator__c, Value__c 
                                                       FROM KYC_Conditions_Config__mdt Where KYC_Creation_Config__c IN: configs.keySet()];
        
        System.debug('Total CMDT Configs Found: ' + configs.size());
        System.debug('Total CMDT Conditions Found: ' + conditions.size());
        
        List<KYC__c> newKycList = new List<KYC__c>();
        MAP<Id, List<KYC_Conditions_Config__mdt>> conditionsMap = new MAP<Id, List<KYC_Conditions_Config__mdt>>();
        
        for(KYC_Conditions_Config__mdt cond : conditions){
            if(!conditionsMap.containsKey(cond.KYC_Creation_Config__c))
                conditionsMap.put(cond.KYC_Creation_Config__c, new List<KYC_Conditions_Config__mdt>());
            conditionsMap.get(cond.KYC_Creation_Config__c).add(cond);
        }
        
        for (sObject record : newRecords) {
            
            for (KYC_Creation_Config__mdt cfg : configs.values()) {
                
                Map<Integer, Boolean> newConditionResults = new Map<Integer, Boolean>();
                Map<Integer, Boolean> oldConditionResults = new Map<Integer, Boolean>();
                Boolean newFinal = false;
                Boolean oldFinal = true;
                
                List<KYC_Conditions_Config__mdt> cfgConditions = conditionsMap.get(cfg.Id);
                
                if (cfgConditions == null || cfgConditions.isEmpty()) {
                    newFinal = true;
                }
                else {
                    
                    for (KYC_Conditions_Config__mdt cond : cfgConditions) {
                        
                        Object newValObj = record.get(cond.Field_API_Name__c);
                        Object oldValObj = null;
                        
                        if (oldRecords != null && oldRecords.containsKey(record.Id)) {
                            oldValObj = oldRecords.get(record.Id).get(cond.Field_API_Name__c);
                        }
                        
                        Boolean newResult = evaluateCondition(newValObj, cond);
                        Boolean oldResult = oldValObj != null
                                ? evaluateCondition(oldValObj, cond)
                                : false;
                        
                        newConditionResults.put(Integer.valueOf(cond.Sequence_Number__c), newResult);
                        oldConditionResults.put(Integer.valueOf(cond.Sequence_Number__c), oldResult);
                    }
                    
                    newFinal = FilterLogicEvaluator.evaluate(cfg.Filter_Logic__c, newConditionResults);
                    
                    if (triggerContext == 'After Update') {
                        oldFinal = FilterLogicEvaluator.evaluate(cfg.Filter_Logic__c, oldConditionResults);
                    }
                }
                
                if (
                    (triggerContext == 'After Insert' && newFinal) ||
                    (triggerContext == 'After Update' && newFinal && !oldFinal)
                ) {
                    
                    KYC__c kyc = new KYC__c();
                    
                    kyc.Status__c = 'Draft';
                    kyc.Valid_From__c = Date.today();
                    kyc.Validity_Period_in_Months__c = cfg.Validity_Period_in_Months__c;
                    if (cfg.Is_Lead_Or_Contact__c == 'Lead')
                        kyc.Lead__c = (Id)record.get(cfg.Linked_Field_API_Name__c);
                    else
                        kyc.Contact__c = (Id)record.get(cfg.Linked_Field_API_Name__c);
                    
                    newKycList.add(kyc);
                }
            }
        }
        
        if (!newKycList.isEmpty()) {
            insert newKycList;
        }
    }
    
    //Evaluates single condition dynamically
    private static Boolean evaluateCondition(Object fieldValue, KYC_Conditions_Config__mdt cond) {
        
        if (fieldValue == null) 
            return false;
        
        String recordValue = String.valueOf(fieldValue);
        String conditionValue = cond.Value__c;
        
        try {
            
            if (cond.Operator__c == 'Equals') {
                return recordValue == conditionValue;
            }
            else if (cond.Operator__c == 'Not Equals') {
                return recordValue != conditionValue;
            }
            else if (cond.Operator__c == 'Greater Than') {
                return Decimal.valueOf(recordValue) > Decimal.valueOf(conditionValue);
            }
            else if (cond.Operator__c == 'Less Than') {
                return Decimal.valueOf(recordValue) < Decimal.valueOf(conditionValue);
            }
            
        } catch (Exception e) {
            System.debug('Condition evaluation error: ' + e.getMessage());
        }
        
        return false;
    }  
}