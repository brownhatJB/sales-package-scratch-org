/**
 * @module            : Real_Estate_Module
 * @description       : Get Filter Query
 * @namespace         :
 * @author            : SREERAM.R
 * @group             : Unit Search
 * @last modified on  : 07-30-2026
 * @last modified by  : SREERAM.R
 **/
public with sharing class UnitSearchFilterQuery {
  // Create global map for query results
  public static Map<String, List<SObject>> myList = new Map<String, List<SObject>>();

  /**
   * @description Method used to get field set used to display
   * @param sObjectName pass the sobject name
   * @param fieldSetName pass the field set name
   * @return returns field and value set
   */
  @AuraEnabled(cacheable=true)
  public static List<String> getFieldSet(
    String sObjectName,
    String fieldSetName,
    Id recordId
  ) {
    List<String> fieldList = new List<String>();
    String keyPrefix = String.valueOf(recordId).substring(0, 3);

    String objectApiName = recordId.getSObjectType().getDescribe().getName();

    // Map<String, Schema.SObjectType> globalDescribeMap = Schema.getGlobalDescribe();

    // for (Schema.SObjectType objType : Schema.getGlobalDescribe().values()) {

    //   system.debug('objType.getDescribe().getKeyPrefix() : ' + objType.getDescribe().getKeyPrefix());
    //   if (objType.getDescribe().getKeyPrefix() == keyPrefix) {
    //     objectApiName = objType.getDescribe().getName();
    //     break;
    //   }
    // }

    // if (objectApiName != 'Opportunity') {
    //   objectApiName = 'Units__c';
    // }

    System.debug('sObjectName: ' + sObjectName);

    System.debug('objectApiName: ' + objectApiName);

    String fieldSetNameSelected = [
      SELECT Field_Set__c
      FROM Filter_Field_Set_Object_Map__mdt
      WHERE Object__c = :objectApiName
      LIMIT 1
    ]
    .Field_Set__c;

    System.debug(fieldSetNameSelected);

    // Initialize the map to store parent object name and its corresponding query
    Map<String, String> queryMap = new Map<String, String>();

    SObjectType objTokens = Schema.getGlobalDescribe().get(sObjectName);
    Schema.DescribeSObjectResult objDescribes = objTokens.getDescribe();

    // Initialize the field set map
    Map<String, Schema.FieldSet> fieldSetMaps = objDescribes.fieldSets.getMap();
    system.debug('fieldSetMaps : ' + fieldSetMaps);
    for (
      Schema.FieldSetMember f : fieldSetMaps.get(fieldSetNameSelected)
        .getFields()
    ) {
      // Describe the field to get its properties
      Schema.DescribeFieldResult fieldResult = objDescribes.fields.getMap()
        .get(f.getFieldPath())
        .getDescribe();

      Schema.DisplayType fieldType = fieldResult.getType();

Boolean supported = true;

switch on fieldType {

    when TEXTAREA,
         ENCRYPTEDSTRING,
         URL,
         MULTIPICKLIST {

        supported = false;

    }

    when else {

        supported = true;

    }

}

if(!supported){
    continue;
}

      if (fieldType == Schema.DisplayType.REFERENCE) {
        // This is a lookup or master-detail relationship field
        List<Schema.SObjectType> referenceTo = fieldResult.getReferenceTo();
        if (!referenceTo.isEmpty()) {
          // Typically, referenceTo will contain only one object type
          String parentObjectName = referenceTo[0].getDescribe().getName();

          String query = 'SELECT Id, Name FROM ' + parentObjectName;

          // Add the query to the map with the parent object name as the key
          queryMap.put(parentObjectName, query);
        }
      }
    }

    myList.clear(); // Clear the previous results

    // Call recursion method with the query map
    recursion(queryMap);

    try {
      // Get the describe result for the object
      SObjectType objToken = Schema.getGlobalDescribe().get(sObjectName);
      Schema.DescribeSObjectResult objDescribe = objToken.getDescribe();
      system.debug('objDescribe under try block : ' + objDescribe);
      INTEGER i = -1;
      // Get the field set map
      Map<String, Schema.FieldSet> fieldSetMap = objDescribe.fieldSets.getMap();
      if (fieldSetMap.containsKey(fieldSetNameSelected)) {
        // Iterate over fields in the field set
        for (
          Schema.FieldSetMember f : fieldSetMap.get(fieldSetNameSelected)
            .getFields()
        ) {
          i++;
          // Describe the field to get its properties
          Schema.DescribeFieldResult fieldResult = objDescribe.fields.getMap()
            .get(f.getFieldPath())
            .getDescribe();
          Schema.DisplayType fieldType = fieldResult.getType();

String operator;

if (fieldResult.isAutoNumber()) {

    operator = '=';

} else {

    switch on fieldType {

        when STRING {
            operator = 'LIKE';
        }

        when PICKLIST,
             BOOLEAN,
             EMAIL,
             PHONE,
             REFERENCE {

            operator = '=';
        }

        when DATE,
             DATETIME,
             CURRENCY,
             DOUBLE,
             INTEGER,
             LONG,
             PERCENT {

            operator = '<=';
        }

        when else {

            operator = '';
        }
    }
}

Boolean supported = true;

switch on fieldType {

    when TEXTAREA,
         ENCRYPTEDSTRING,
         URL,
         MULTIPICKLIST {

        supported = false;
    }

    when else {
        supported = true;
    }
}

if (!supported) {
    continue;
}

          // Convert the Schema.DisplayType to a more readable format
          String readableFieldType = fieldType.name();
String jsonPart =
    '{"label":"' +
    f.getLabel() +
    '","name":"' +
    f.getFieldPath() +
    '","type":"' +
    readableFieldType +
    '","operator":"' +
    operator +
    '","options":null}';

          // If the field is a picklist or multi-picklist, get picklist values
          if (
            readableFieldType == 'PICKLIST'
          ) {
            List<Schema.PicklistEntry> picklistEntries = fieldResult.getPicklistValues();
            List<String> picklistValues = new List<String>();

            for (Schema.PicklistEntry entry : picklistEntries) {
              // Skip inactive picklist values
              if (!entry.isActive()) {
                continue;
              }
              String option =
                '{"value":"' +
                entry.getValue() +
                '","label":"' +
                entry.getLabel() +
                '"}';
              picklistValues.add(option);
            }

            // Replace "options":null with the actual picklist options
            String optionsValue = '[' + String.join(picklistValues, ',') + ']';
            jsonPart = jsonPart.replace(
              '"options":null',
              '"options":' + optionsValue
            );
          }
          if (readableFieldType == 'REFERENCE') {
            // This is a lookup or master-detail relationship field
            List<Schema.SObjectType> referenceTo = fieldResult.getReferenceTo();

            // Typically, referenceTo will contain only one object type
            String parentObjectName = referenceTo[0].getDescribe().getName();

            // Retrieve the records from the map based on the parent object name
            List<SObject> records = myList.get(parentObjectName);

            // Initialize a list to store the JSON strings
            List<String> picklistValues = new List<String>();

            // Loop through the records and construct the JSON string
            for (SObject record : records) {
              String nameValue = (String) record.get('Name');

              // Construct the JSON string for each record
String option =
'{"value":"' +
record.Id +
'","label":"' +
String.escapeSingleQuotes(nameValue) +
'"}';

              // Add the JSON string to the list
              picklistValues.add(option);
            }

            // Join the JSON strings into a JSON array format
            String optionsValue = '[' + String.join(picklistValues, ',') + ']';
            System.debug(optionsValue);

            jsonPart = jsonPart.replace(
              '"options":null',
              '"options":' + optionsValue
            );
          }
          if (readableFieldType == 'BOOLEAN') {
            String trueOption = '{"value":"true","label":"True"}';

            String falseOption = '{"value":"false","label":"False"}';

            List<String> picklistValues = new List<String>();
            picklistValues.add(trueOption);
            picklistValues.add(falseOption);
            String optionsValue = '[' + String.join(picklistValues, ',') + ']';
            jsonPart = jsonPart.replace(
              '"options":null',
              '"options":' + optionsValue
            );
          }
          // Add the jsonPart to the field list
          fieldList.add(jsonPart);
        }
      }
    } catch (Exception ex) {
      fieldList.add(
        '{"error":"Error at line ' +
          ex.getLineNumber() +
          ': ' +
          ex.getMessage() +
          '"}'
      );
    }

    return fieldList;
  }

  public static void recursion(Map<String, String> queryMap) {
    if (!queryMap.isEmpty()) {
      // Get the first entry in the map (Map is unordered, so this will be arbitrary)
      String parentObjectName = String.escapeSingleQuotes(
        queryMap.keySet().iterator().next()
      );
      String query = String.escapeSingleQuotes(queryMap.get(parentObjectName));

      // Query for the records and add them to the map
      List<SObject> records = Database.query(String.escapeSingleQuotes(query));
      myList.put(parentObjectName, records);

      // Remove processed query from the map
      queryMap.remove(parentObjectName);

      // Do recursion
      recursion(queryMap);
    }
  }
}