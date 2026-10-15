/**
* @module            : Real_Estate_Module
* @description       : Dynamic KYC validation engine. 
*                      Validates existence and status of related KYC records 
*                      based on Custom Metadata configuration and restricts 
*                      record operations dynamically.
* @namespace         :
* @author            : SHUBHAM GUPTA
* @group             : DYNAMIC KYC CONTROL FRAMEWORK
* @testClass		  : 
* @last modified on  : 
* @last modified by  : 
**/
public with sharing class KYCValidationService implements TriggerAction.BeforeInsert, TriggerAction.BeforeUpdate {
    
    @TestVisible private static List<KYC_Process_Control__mdt> mockConfigs;
	@TestVisible private static List<KYC_Conditions_Config__mdt> mockConditions;
    
    // ============= BEFORE INSERT =======================
    public void beforeInsert(List<sObject> records){
        
        System.debug('Entered beforeInsert ' + records.size());
        validate(records, new Map<Id, sObject>{}, 'Before Insert');
    }
    
    // =============== BEFORE UPDATE ==========================
    public void beforeUpdate(List<sObject> newRecords, List<sObject> oldRecords){
        
        // Map old records by Id for quick comparison
        Map<Id, sObject> oldRecordsMap = new Map<Id, sObject>();
        
        for (sObject oldRec : oldRecords) {
            oldRecordsMap.put(oldRec.Id, oldRec);
        }
        
        System.debug('Entered beforeUpdate ' + newRecords.size() + ' ' + oldRecords.size());
        validate(newRecords, oldRecordsMap, 'Before Update');
    }
    
    //CORE VALIDATION ENGINE
    //---------------------------------------------
    //1. Fetch relevant CMDT configuration
    //2. Collect parent IDs (Lead/Contact)
    //3. Fetch latest KYC records
    //4. Evaluate metadata conditions
    //5. Apply enforcement mode (Block/Warning)
    public static void validate(List<sObject> newRecords, Map<Id, sObject> oldRecords, String actionType) {
        
        if (newRecords == null || newRecords.isEmpty()) 
            return;
        
        // Identify object dynamically
        String objectName = newRecords[0].getSObjectType().getDescribe().getName();
        
        // Fetch active metadata configs for this object & event
        MAP<Id, KYC_Process_Control__mdt> configs = new MAP<Id, KYC_Process_Control__mdt>([SELECT Object_API_Name__c, Event__c, Linked_Field_API_Name__c,
                                                                                           Filter_Logic__c,  Enforcement_Mode__c, Error_Warning_Message__c,
                                                                                           Is_Active__c, Id FROM KYC_Process_Control__mdt
                                                                                           WHERE Object_API_Name__c =:objectName and Is_Active__c = true 
                                                                                           and Event__c =: actionType]);
        
        if(configs.isEmpty()) 
            return;
        
        // Assumption: Only one linked field per object/event
        String linkedFieldApiName = configs.values()[0].Linked_Field_API_Name__c;
        
        // Fetch child condition metadata
        List<KYC_Conditions_Config__mdt> conditions = [SELECT Id, KYC_Process_Control__c, Sequence_Number__c, Field_API_Name__c, Operator__c, Value__c 
                                                       FROM KYC_Conditions_Config__mdt Where KYC_Process_Control__c IN: configs.keySet()];
        
        System.debug('Total CMDT Configs Found: ' + configs.size());
        System.debug('Total CMDT Conditions Found: ' + conditions.size());
        
        MAP<Id, List<KYC_Conditions_Config__mdt>> conditionsMap = new MAP<Id, List<KYC_Conditions_Config__mdt>>();
        
        for(KYC_Conditions_Config__mdt cond : conditions){
            if(!conditionsMap.containsKey(cond.KYC_Process_Control__c))
                conditionsMap.put(cond.KYC_Process_Control__c, new List<KYC_Conditions_Config__mdt>());
            conditionsMap.get(cond.KYC_Process_Control__c).add(cond);
        }
                
        //Collect parent IDs (Lead/Contact)
        Set<Id> parentIds = new Set<Id>(); 
        
        for (SObject record : newRecords) {
            
            if (!record.getSObjectType().getDescribe().fields.getMap().containsKey(linkedFieldApiName))
                continue;
            
            Id parentId = (Id) record.get(linkedFieldApiName);
            if (parentId != null) {
                parentIds.add(parentId);
            }
        }
        
        if(parentIds.isEmpty()) 
            return;
        
        //Fetch latest KYC records Ordered by CreatedDate DESC so first occurrence is latest
        List <KYC__c> kycs = [SELECT Id, Status__c, Lead__c, Contact__c FROM KYC__c
                              WHERE Lead__c IN: parentIds OR Contact__c IN: parentIds 
                              ORDER BY CreatedDate DESC];
        
        System.debug('Total kycs Found: ' + kycs.size());
        
        //Map parentId → latest KYC record
        Map<Id, KYC__c> latestKycByParent = new Map<Id, KYC__c>();
        
        for (KYC__c kyc : kycs) {
            
            Id key = kyc.Contact__c != null ? kyc.Contact__c : kyc.Lead__c;
            
            // Store only first occurrence (latest due to DESC order)
            if(!latestKycByParent.containsKey(key)) {
                latestKycByParent.put(key, kyc);
            }
        }
        
        //Evaluate each record against metadata conditions
        for (SObject record : newRecords) {
            
            Id parentId = (Id)record.get(linkedFieldApiName);
            if (parentId == null) 
                continue;
            KYC__c kyc = latestKycByParent.get(parentId);
            
            for (KYC_Process_Control__mdt cfg : configs.values()) {
                
                Boolean newFinal = false;
                Boolean oldFinal = true;
                Boolean performAction = false;
                
                Map<Integer, Boolean> newConditionResults = new Map<Integer, Boolean>();
                Map<Integer, Boolean> oldConditionResults = new Map<Integer, Boolean>();
                
                List<KYC_Conditions_Config__mdt> cfgConditions = conditionsMap.get(cfg.Id);
                
                // If no conditions treated as always applicable
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
                    
                    if (actionType == 'Before Update') {
                        oldFinal = FilterLogicEvaluator.evaluate(cfg.Filter_Logic__c, oldConditionResults);
                    }
                }
                
                //Decide enforcement
                if (
                    (actionType == 'Before Insert' && newFinal) ||
                    (actionType == 'Before Update' && newFinal && !oldFinal)
                ) {
                    // If no KYC or KYC not approved → enforce
                    if (kyc == null || kyc.Status__c != 'Approved') {
                        System.debug('kyc : ' + kyc);
                        performAction = true;
                    }    
                }
                
                //Apply enforcement mode
                if (performAction) {
                    if (cfg.Enforcement_Mode__c == 'Block') {
                        System.debug('Inside Block');
                        record.addError(cfg.Error_Warning_Message__c);
                    }
                    else if (cfg.Enforcement_Mode__c == 'Warning') {
                        System.debug('Inside Warning :- Warning Msg ' + cfg.Error_Warning_Message__c);
                        KYCWarningEventPublisher.publishWarning(
                            record.Id,
                            objectName,
                            cfg.Error_Warning_Message__c
                        );
                    }
                }
            }
        }
    }
    
    //Evaluates single condition dynamically
    @TestVisible
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