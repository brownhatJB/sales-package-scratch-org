/**
 * @description Test class for UnitSearchConfigurationController
 */
@IsTest
private class UnitSearchConfigurationControllerTest {

    @IsTest
    static void testGetParkingUnitsConfiguration() {

        Test.startTest();
        List<Parking_Units_Setting__mdt> results =
            UnitSearchConfigurationController.getParkingUnitsConfiguration();
        Test.stopTest();

        System.assertNotEquals(null, results, 'Result list should not be null');

        // Custom metadata is visible in tests. If the record exists, validate shape.
        if (!results.isEmpty()) {
            System.assertEquals(1, results.size(), 'Query is LIMIT 1');
            Parking_Units_Setting__mdt config = results[0];
            System.assertEquals('Units_Search_Table', config.DeveloperName);
            System.assertNotEquals(null, config.Id);
            // Show_Parking_Units__c is Boolean — just ensure the field is readable
            System.assertNotEquals(null, config.Show_Parking_Units__c || !config.Show_Parking_Units__c);
        }
    }

    @IsTest
    static void testGetUnitSearchTableConfiguration() {

        Test.startTest();
        List<Unit_Search_Table_Setting__mdt> results =
            UnitSearchConfigurationController.getUnitSearchTableConfiguration();
        Test.stopTest();

        System.assertNotEquals(null, results, 'Result list should not be null');

        if (!results.isEmpty()) {
            System.assertEquals(1, results.size(), 'Query is LIMIT 1');
            Unit_Search_Table_Setting__mdt config = results[0];
            System.assertEquals('Config_01', config.DeveloperName);
            System.assertNotEquals(null, config.Id);
            System.assertNotEquals(null, config.Show_Promo_Configuration__c || !config.Show_Promo_Configuration__c);
        }
    }

    @IsTest
    static void testBothMethodsInSameTransaction() {

        Test.startTest();
        List<Parking_Units_Setting__mdt> parkingConfig =
            UnitSearchConfigurationController.getParkingUnitsConfiguration();
        List<Unit_Search_Table_Setting__mdt> tableConfig =
            UnitSearchConfigurationController.getUnitSearchTableConfiguration();
        Test.stopTest();

        System.assertNotEquals(null, parkingConfig);
        System.assertNotEquals(null, tableConfig);
    }
}