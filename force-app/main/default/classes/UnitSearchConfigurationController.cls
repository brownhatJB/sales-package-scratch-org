public with sharing class UnitSearchConfigurationController {
    
    @AuraEnabled(cacheable=true)
    public static List<Parking_Units_Setting__mdt> getParkingUnitsConfiguration() {

        return [
            SELECT 
                Id, Label, DeveloperName, Show_Parking_Units__c
            FROM Parking_Units_Setting__mdt
            WHERE DeveloperName = 'Units_Search_Table'
            LIMIT 1
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<Unit_Search_Table_Setting__mdt> getUnitSearchTableConfiguration() {

        return [
            SELECT
                Id, Label, DeveloperName, Show_Promo_Configuration__c
            FROM Unit_Search_Table_Setting__mdt
            WHERE DeveloperName = 'Config_01'
            LIMIT 1
        ];
    }
}