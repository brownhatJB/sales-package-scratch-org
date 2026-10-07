/**
 * @module             : Real_Estate_Module
 * @description        :get field set to display in json format
 * @namespace          :
 * @author            : SREERAM.R
 * @group              : Unit Search
 * @last modified on   : 08-16-2024
 * @last modified by   : SREERAM.R
 **/
public with sharing class UnitSearchFieldListPreferenceSearch {
  /**
   * @description Method used to get field set used to display
   * @param sObjectName pass the sobject name
   * @param fieldSetName pass the field set name
   * @param recordId pass the field set name
   * @return returns JSON text with names and api names of columns to display
   */
  @AuraEnabled(cacheable=true)
  public static String getFieldSet(String sObjectName, String fieldSetName, Id recordId) {
    
    List<String> fieldList = new List<String>();
    try {
    String keyPrefix = String.valueOf(recordId).substring(0, 3);
    String objectApiName = recordId.getSObjectType().getDescribe().getName();

    // for (Schema.SObjectType objType : Schema.getGlobalDescribe().values()) {
    //   if (objType.getDescribe().getKeyPrefix() == keyPrefix) {
    //     objectApiName = objType.getDescribe().getName();
    //     break;
    //   }
    // }

    System.debug('objectApiName: ' + objectApiName);

    String fieldSetNameSelected = [
      SELECT pflexmet__Field_Set__c
      FROM pflexmet__Unit_Search_Column_Object_Map__mdt
      WHERE pflexmet__Object__c = :objectApiName
      LIMIT 1
    ]
    .pflexmet__Field_Set__c;

      SObjectType objToken = Schema.getGlobalDescribe().get(sObjectName);
      Schema.DescribeSObjectResult d = objToken.getDescribe();
      Map<String, Schema.FieldSet> fieldSetMap = d.fieldSets.getMap();
      if (fieldSetMap.containsKey(fieldSetNameSelected)) {
        for (Schema.FieldSetMember f : fieldSetMap.get(fieldSetNameSelected).getFields()) {
          if (f.getLabel() == 'propertyImage') {
            String jsonPart = '{"label":"Property Picture","name":"propertyImage__c","type":"customPictureType","typeAttributes":{"pictureUrl":{"fieldName":"propertyImage__c"}},"cellAttributes":{"alignment":"center"}}';
            fieldList.add(jsonPart);
          } else {
            String jsonPart = '{"label":"' + f.getLabel() + '","name":"' + f.getFieldPath() + '"}';
            fieldList.add(jsonPart);
          }
        }
      }
    } catch (Exception ex) {
      fieldList.add('{"error":"Error at line ' + ex.getLineNumber() + ': ' + ex.getMessage() + '"}');
    }
    return '[' + String.join(fieldList, ',') + ']';
  }
}