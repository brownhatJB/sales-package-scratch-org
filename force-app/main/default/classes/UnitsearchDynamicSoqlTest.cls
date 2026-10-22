/**
 * @module            : Real_Estate_Module
 * @description       :
 * @namespace         :
 * @author            : Jouhar C
 * @group             :
 * @last modified on  : 22-10-2026
 * @last modified by  : Jouhar C
 **/
@IsTest
private class UnitsearchDynamicSoqlTest {

    private static User getTestUser() {
        return TestUserFactory.createUserWithPackageAccess();
    }

    @TestSetup
    static void setupData() {
        Project__c proj = new Project__c(
            Name          = 'Test Project',
            Stage__c      = 'Planning',
            UOM__c        = 'Sq. Ft',
            Total_Area__c = 10000
        );
        insert proj;

        Properties__c prop = new Properties__c(
            Name                  = 'Test Property',
            Project__c            = proj.Id,
            Stage__c              = 'Under Construction',
            Property_Ownership__c = 'Fully Owned',
            UOM__c                = 'Sq. Ft',
            Total_Area__c         = 1000
        );
        insert prop;

        List<Units__c> units = new List<Units__c>{
            new Units__c(
                Name                     = 'Unit-101',
                Project__c               = proj.Id,
                Properties__c            = prop.Id,
                Floor__c                 = 1,
                View__c                  = 'Lake',
                Type__c                  = 'Apartment',
                Bedrooms__c              = 2,
                Furnishing_Status__c     = 'Furnished',
                Unit_Price__c            = 1000000,
                Current_Selling_Price__c = 1000000,
                Total_Area__c            = 1200,
                Status__c                = 'Available'
            ),
            new Units__c(
                Name                     = 'Unit-102',
                Project__c               = proj.Id,
                Properties__c            = prop.Id,
                Floor__c                 = 2,
                View__c                  = 'Lake',
                Type__c                  = 'Apartment',
                Bedrooms__c              = 3,
                Furnishing_Status__c     = 'Furnished',
                Unit_Price__c            = 1500000,
                Current_Selling_Price__c = 1500000,
                Total_Area__c            = 1500,
                Status__c                = 'Available'
            ),
            // Parking – must be excluded by base WHERE Type__c != 'Parking'
            new Units__c(
                Name                     = 'Park-001',
                Project__c               = proj.Id,
                Properties__c            = prop.Id,
                Type__c                  = 'Parking',
                Unit_Price__c            = 50000,
                Current_Selling_Price__c = 50000,
                Total_Area__c            = 100,
                Status__c                = 'Available'
            )
        };
        // Adjust required fields if your org needs more
        insert units;
    }

    private static String emptyFiltersJson() {
        return '{}';
    }

    private static String buildFilter(
        String fieldName,
        Object value,
        String operator,
        String type
    ) {
        Map<String, Object> fieldMap = new Map<String, Object>{
            'value'    => value,
            'operator' => operator,
            'type'     => type
        };
        Map<String, Object> filters = new Map<String, Object>{
            fieldName => fieldMap
        };
        return JSON.serialize(filters);
    }

    // --------------------------------------------------
    // getFilterValues
    // --------------------------------------------------
    @IsTest
    static void testGetFilterValues() {
        User testUser = getTestUser();

        System.runAs(testUser) {
            Test.startTest();
            FilterValues result = UnitsearchDynamicSoql.getFilterValues();
            Test.stopTest();

            System.assertNotEquals(null, result, 'FilterValues should not be null');
        }
    }

    // --------------------------------------------------
    // getunits – no extra filters
    // --------------------------------------------------
    @IsTest
    static void testGetUnits_NoFilters() {
        User testUser = getTestUser();

        System.runAs(testUser) {
            Test.startTest();
            List<Units__c> units = UnitsearchDynamicSoql.getunits(
                emptyFiltersJson(),
                'Name, Status__c, Type__c, Unit_Price__c'
            );
            Test.stopTest();

            System.assertNotEquals(null, units);
            // Available + not Parking → at least the two apartments
            System.assert(units.size() >= 2, 'Should return available non-parking units');
            for (Units__c u : units) {
                System.assertEquals('Available', u.Status__c);
                System.assertNotEquals('Parking', u.Type__c);
            }
        }
    }

    // --------------------------------------------------
    // STRING / PICKLIST filter
    // --------------------------------------------------
    @IsTest
    static void testGetUnits_StringFilter() {
        User testUser = getTestUser();
        String filterJson = buildFilter('Type__c', 'Apartment', '=', 'PICKLIST');

        System.runAs(testUser) {
            Test.startTest();
            List<Units__c> units = UnitsearchDynamicSoql.getunits(
                filterJson,
                'Name, Type__c, Status__c'
            );
            Test.stopTest();

            System.assertNotEquals(null, units);
            System.assert(units.size() >= 1);
            for (Units__c u : units) {
                System.assertEquals('Apartment', u.Type__c);
            }
        }
    }

    // --------------------------------------------------
    // LIKE filter
    // --------------------------------------------------
    @IsTest
    static void testGetUnits_LikeFilter() {
        User testUser = getTestUser();
        String filterJson = buildFilter('Name', 'Unit-101', 'LIKE', 'STRING');

        System.runAs(testUser) {
            Test.startTest();
            List<Units__c> units = UnitsearchDynamicSoql.getunits(
                filterJson,
                'Name, Status__c'
            );
            Test.stopTest();

            System.assertNotEquals(null, units);
            System.assert(units.size() >= 1);
            for (Units__c u : units) {
                System.assert(u.Name.contains('Unit-101'));
            }
        }
    }

    // --------------------------------------------------
    // NUMERIC filter (CURRENCY / DOUBLE)
    // --------------------------------------------------
    @IsTest
    static void testGetUnits_NumericFilter() {
        User testUser = getTestUser();
        String filterJson = buildFilter('Unit_Price__c', 1200000, '>=', 'CURRENCY');

        System.runAs(testUser) {
            Test.startTest();
            List<Units__c> units = UnitsearchDynamicSoql.getunits(
                filterJson,
                'Name, Unit_Price__c'
            );
            Test.stopTest();

            System.assertNotEquals(null, units);
            for (Units__c u : units) {
                System.assert(u.Unit_Price__c >= 1200000);
            }
        }
    }

    // --------------------------------------------------
    // Null filter value – skipped
    // --------------------------------------------------
    @IsTest
    static void testGetUnits_NullFilterValue() {
        User testUser = getTestUser();

        Map<String, Object> fieldMap = new Map<String, Object>{
            'value'    => null,
            'operator' => '=',
            'type'     => 'STRING'
        };
        Map<String, Object> filters = new Map<String, Object>{
            'Name' => fieldMap
        };
        String filterJson = JSON.serialize(filters);

        System.runAs(testUser) {
            Test.startTest();
            List<Units__c> units = UnitsearchDynamicSoql.getunits(
                filterJson,
                'Name, Status__c'
            );
            Test.stopTest();

            System.assertNotEquals(null, units);
            System.assert(units.size() >= 2, 'Null filter value should be ignored');
        }
    }

    // --------------------------------------------------
    // Multiple filters combined
    // --------------------------------------------------
    @IsTest
    static void testGetUnits_MultipleFilters() {
        User testUser = getTestUser();

        Map<String, Object> filters = new Map<String, Object>{
            'Type__c' => new Map<String, Object>{
                'value'    => 'Apartment',
                'operator' => '=',
                'type'     => 'PICKLIST'
            },
            'Unit_Price__c' => new Map<String, Object>{
                'value'    => 1000000,
                'operator' => '>=',
                'type'     => 'CURRENCY'
            }
        };
        String filterJson = JSON.serialize(filters);

        System.runAs(testUser) {
            Test.startTest();
            List<Units__c> units = UnitsearchDynamicSoql.getunits(
                filterJson,
                'Name, Type__c, Unit_Price__c'
            );
            Test.stopTest();

            System.assertNotEquals(null, units);
            for (Units__c u : units) {
                System.assertEquals('Apartment', u.Type__c);
                System.assert(u.Unit_Price__c >= 1000000);
            }
        }
    }

    // --------------------------------------------------
    // Invalid JSON / bad query → exception
    // --------------------------------------------------
    @IsTest
    static void testGetUnits_InvalidJson() {
        User testUser = getTestUser();
        Boolean threw = false;

        System.runAs(testUser) {
            Test.startTest();
            try {
                UnitsearchDynamicSoql.getunits(
                    'not-valid-json',
                    'Name'
                );
            } catch (Exception e) {
                threw = true;
            }
            Test.stopTest();
        }

        System.assert(threw, 'Invalid JSON should throw');
    }
}