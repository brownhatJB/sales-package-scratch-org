/**
* @module            : Real_Estate_Module
* @description       : Publishes KYC warning messages using Platform Events.
*                      This class is responsible for sending non-blocking 
*                      warning notifications to the UI layer (LWC) via 
*                      KYC_Warning_Event__e.
* @namespace         :
* @author            : SHUBHAM GUPTA
* @group             : DYNAMIC KYC CONTROL FRAMEWORK
* @testClass		 : 
* @last modified on  : 
* @last modified by  : 
**/
public with sharing class KYCWarningEventPublisher {
    
    public static void publishWarning(
        Id recordId,
        String objectName,
        String message
    ) {
        
        KYC_Warning_Event__e eventMsg = new KYC_Warning_Event__e(
            Record_Id__c = String.valueOf(recordId),
            Object_Name__c = objectName,
            Message__c = message,
            User_Id__c = UserInfo.getUserId()
        );
        
        Database.SaveResult result = EventBus.publish(eventMsg);
        
        if (!result.isSuccess()) {
            System.debug('Failed to publish KYC warning event');
        }
    }
}