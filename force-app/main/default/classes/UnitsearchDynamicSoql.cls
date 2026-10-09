/**
 * @module            : Real_Estate_Module
 * @description       : get units and other records for unit search and preference unit search
 * @namespace         :
 * @author            : SREERAM.R
 * @group             : UNIT SEARCH
 * @last modified on  : 08-06-2026
 * @last modified by  : SREERAM.R
 **/
public with sharing class UnitsearchDynamicSoql {
  //get filter class
  @AuraEnabled(cacheable=true)
  public static FilterValues getFilterValues() {
    return new FilterValues();
  }
  /**
   * @description get units based using dynamic soql
   * @param filterValues wrapper class for filter variables
   * @return Database.query(query) returns list of units
   */
  @AuraEnabled(cacheable=true)
  public static List<Units__c> getunits(String filterJson, String fields) {
    try {

Map<String,Object> filters =
    (Map<String,Object>)JSON.deserializeUntyped(filterJson);
    System.debug('Filters : ' + filters);

String query =
    'SELECT Id , Default_Payment_Plan__c, ' + fields +
    ' FROM Units__c' +
    ' WHERE Status__c = \'Available\'' +
    ' AND Type__c != \'Parking\'';

for (String fieldName : filters.keySet()) {

    Map<String, Object> field =
        (Map<String, Object>) filters.get(fieldName);

    if (field == null || field.get('value') == null) {
        continue;
    }

    String value = String.valueOf(field.get('value'));
    String operator = String.valueOf(field.get('operator'));
    String type = String.valueOf(field.get('type'));

    System.debug('Field : ' + fieldName);
    System.debug('Value : ' + value);
    System.debug('Operator : ' + operator);
    System.debug('Type : ' + type);

if (operator == 'LIKE') {

    query +=
        ' AND ' + fieldName +
        ' LIKE \'%' +
        String.escapeSingleQuotes(value) +
        '%\'';

}
// String based fields
else if (
    type == 'STRING' ||
    type == 'REFERENCE' ||
    type == 'PICKLIST' ||
    type == 'EMAIL' ||
    type == 'PHONE' ||
    type == 'AUTONUMBER'
) {

    query +=
        ' AND ' + fieldName +
        ' ' + operator +
        ' \'' +
        String.escapeSingleQuotes(value) +
        '\'';

}
// Boolean fields
else if (type == 'BOOLEAN') {

    query +=
        ' AND ' + fieldName +
        ' ' + operator +
        ' ' +
        value.toLowerCase();

}
// Numeric fields
else if (
    type == 'DOUBLE' ||
    type == 'INTEGER' ||
    type == 'LONG' ||
    type == 'PERCENT' ||
    type == 'CURRENCY'
) {

    query +=
        ' AND ' + fieldName +
        ' ' + operator +
        ' ' +
        value;

}
// Date / DateTime fields
else if (
    type == 'DATE' ||
    type == 'DATETIME'
) {

    query +=
        ' AND ' + fieldName +
        ' ' + operator +
        ' ' +
        value;

}
}

query += ' ORDER BY Name ASC NULLS LAST';
System.debug('Final Query: ' + query);

return Database.query(query);
    } catch (Exception e) {
      throw e;
    }
  }
}