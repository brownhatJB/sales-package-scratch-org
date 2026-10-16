@IsTest
private class LeadJointOwnerControllerTest {

    private static User getTestUser() {
        return TestUserFactory.createUserWithPackageAccess();
    }

    @TestSetup
    static void setupData() {
        Account acc = new Account(Name = 'Joint Owner Test Account');
        insert acc;

        List<Contact> contacts = new List<Contact>{
            new Contact(
                FirstName = 'Primary',
                LastName  = 'Owner',
                AccountId = acc.Id,
                Email     = 'primary.owner@example.com'
            ),
            new Contact(
                FirstName = 'Second',
                LastName  = 'Owner',
                AccountId = acc.Id,
                Email     = 'second.owner@example.com'
            ),
            new Contact(
                FirstName = 'Third',
                LastName  = 'Owner',
                AccountId = acc.Id,
                Email     = 'third.owner@example.com'
            )
        };
        insert contacts;

        Lead lead = new Lead(
            FirstName = 'Test',
            LastName  = 'Lead',
            Company   = 'Test Company',
            Status    = 'Open - Not Contacted',
            pflexmet__Buyer_Type__c = 'Individual'
        );
        insert lead;

        // One existing joint owner for update / delete scenarios
        pflexmet__Joint_Owner__c existingOwner = new pflexmet__Joint_Owner__c(
            pflexmet__Lead__c               = lead.Id,
            pflexmet__Customer_Name__c      = contacts[0].Id,
            pflexmet__Customer_Type__c      = getValidCustomerType(),
            pflexmet__Ownership_Order__c    = 1,
            pflexmet__Percentage_of_Owner__c = 100,
            pflexmet__IsPrimary__c          = true
        );
        insert existingOwner;
    }

    /** Returns the first active picklist value for Customer Type. */
    private static String getValidCustomerType() {
        for (Schema.PicklistEntry entry :
             pflexmet__Joint_Owner__c.pflexmet__Customer_Type__c
                 .getDescribe().getPicklistValues()) {
            if (entry.isActive()) {
                return entry.getValue();
            }
        }
        // Fallback if no active values (should not happen in a configured org)
        return 'Individual';
    }

    private static Lead getTestLead() {
        return [
            SELECT Id, pflexmet__Buyer_Type__c
            FROM Lead
            WHERE LastName = 'Lead'
            LIMIT 1
        ];
    }

    private static List<Contact> getTestContacts() {
        return [
            SELECT Id, FirstName, LastName
            FROM Contact
            WHERE Email LIKE '%owner@example.com'
            ORDER BY FirstName
        ];
    }

    private static pflexmet__Joint_Owner__c getExistingOwner() {
        return [
            SELECT Id, pflexmet__Lead__c, pflexmet__Customer_Name__c,
                   pflexmet__Customer_Type__c, pflexmet__Ownership_Order__c,
                   pflexmet__Percentage_of_Owner__c, pflexmet__IsPrimary__c
            FROM pflexmet__Joint_Owner__c
            LIMIT 1
        ];
    }

    private static String buildOwnerJson(
        Id ownerId,
        Id contactId,
        String customerType,
        Integer order,
        Decimal percentage,
        Boolean isPrimary
    ) {
        Map<String, Object> row = new Map<String, Object>();
        if (ownerId != null) {
            row.put('id', String.valueOf(ownerId));
        }
        row.put('customerContactId', String.valueOf(contactId));
        row.put('customerType', customerType);
        row.put('ownershipOrder', order);
        row.put('ownershipPercentage', percentage);
        row.put('isPrimary', isPrimary);
        return JSON.serialize(new List<Object>{ row });
    }

    private static String buildOwnersJson(List<Map<String, Object>> rows) {
        return JSON.serialize(rows);
    }

    // --------------------------------------------------
    // getInitialData
    // --------------------------------------------------

    @IsTest
    static void testGetInitialData_Success() {
        User testUser = getTestUser();
        Lead lead = getTestLead();

        System.runAs(testUser) {
            Test.startTest();
            Map<String, Object> result =
                LeadJointOwnerController.getInitialData(lead.Id);
            Test.stopTest();

            System.assertNotEquals(null, result);
            System.assert(result.containsKey('buyerType'));
            System.assert(result.containsKey('owners'));
            System.assert(result.containsKey('customerTypeValues'));

            List<Object> owners = (List<Object>) result.get('owners');
            System.assertEquals(1, owners.size(), 'Should return the existing owner');

            List<Object> typeValues =
                (List<Object>) result.get('customerTypeValues');
            System.assert(typeValues.size() > 0, 'Should return active customer types');
        }
    }

    @IsTest
    static void testGetInitialData_NullLeadId() {
        User testUser = getTestUser();

        System.runAs(testUser) {
            Test.startTest();
            Boolean threw = false;
            try {
                LeadJointOwnerController.getInitialData(null);
            } catch (AuraHandledException e) {
                threw = true;
            }
            Test.stopTest();
            System.assert(threw, 'Should throw for null leadId');
        }
    }

    @IsTest
    static void testGetInitialData_InvalidIdType() {
        User testUser = getTestUser();
        Contact con = getTestContacts()[0];

        System.runAs(testUser) {
            Test.startTest();
            Boolean threw = false;
            try {
                // Pass a Contact Id instead of Lead Id
                LeadJointOwnerController.getInitialData(con.Id);
            } catch (AuraHandledException e) {
                threw = true;
            }
            Test.stopTest();
            System.assert(threw, 'Should throw for non-Lead Id');
        }
    }

    // --------------------------------------------------
    // saveOwners – success paths
    // --------------------------------------------------

    @IsTest
    static void testSaveOwners_CreateTwoOwners() {
        User testUser = getTestUser();
        Lead lead = getTestLead();
        List<Contact> contacts = getTestContacts();
        String customerType = getValidCustomerType();

        // Delete the existing sole owner first so we start clean,
        // then create two new owners.
        pflexmet__Joint_Owner__c existing = getExistingOwner();

        List<Map<String, Object>> rows = new List<Map<String, Object>>{
            new Map<String, Object>{
                'customerContactId'   => String.valueOf(contacts[0].Id),
                'customerType'        => customerType,
                'ownershipOrder'      => 1,
                'ownershipPercentage' => 60,
                'isPrimary'           => true
            },
            new Map<String, Object>{
                'customerContactId'   => String.valueOf(contacts[1].Id),
                'customerType'        => customerType,
                'ownershipOrder'      => 2,
                'ownershipPercentage' => 40,
                'isPrimary'           => false
            }
        };

        System.runAs(testUser) {
            Test.startTest();
            // Remove existing owner, then insert two new ones
            Map<String, String> result = LeadJointOwnerController.saveOwners(
                lead.Id,
                buildOwnersJson(rows),
                new List<Id>{ existing.Id }
            );
            Test.stopTest();

            System.assertNotEquals(null, result.get('message'));
        }

        List<pflexmet__Joint_Owner__c> owners = [
            SELECT Id, pflexmet__IsPrimary__c, pflexmet__Ownership_Order__c,
                   pflexmet__Percentage_of_Owner__c
            FROM pflexmet__Joint_Owner__c
            WHERE pflexmet__Lead__c = :lead.Id
            ORDER BY pflexmet__Ownership_Order__c
        ];
        System.assertEquals(2, owners.size());
        System.assertEquals(true, owners[0].pflexmet__IsPrimary__c);
        System.assertEquals(1, owners[0].pflexmet__Ownership_Order__c);

        Lead updatedLead = [
            SELECT pflexmet__Buyer_Type__c FROM Lead WHERE Id = :lead.Id
        ];
        System.assertEquals('Joint Owner', updatedLead.pflexmet__Buyer_Type__c);
    }

    @IsTest
    static void testSaveOwners_UpdateExisting() {
        User testUser = getTestUser();
        Lead lead = getTestLead();
        pflexmet__Joint_Owner__c existing = getExistingOwner();
        List<Contact> contacts = getTestContacts();
        String customerType = getValidCustomerType();

        List<Map<String, Object>> rows = new List<Map<String, Object>>{
            new Map<String, Object>{
                'id'                  => String.valueOf(existing.Id),
                'customerContactId'   => String.valueOf(contacts[0].Id),
                'customerType'        => customerType,
                'ownershipOrder'      => 1,
                'ownershipPercentage' => 100,
                'isPrimary'           => true
            }
        };

        System.runAs(testUser) {
            Test.startTest();
            Map<String, String> result = LeadJointOwnerController.saveOwners(
                lead.Id,
                buildOwnersJson(rows),
                new List<Id>()
            );
            Test.stopTest();

            System.assert(result.get('message').contains('saved'));
        }

        pflexmet__Joint_Owner__c updated = [
            SELECT pflexmet__Percentage_of_Owner__c
            FROM pflexmet__Joint_Owner__c
            WHERE Id = :existing.Id
        ];
        System.assertEquals(100, updated.pflexmet__Percentage_of_Owner__c);
    }

    @IsTest
    static void testSaveOwners_DeleteAll_SetsIndividual() {
        User testUser = getTestUser();
        Lead lead = getTestLead();
        pflexmet__Joint_Owner__c existing = getExistingOwner();

        // Empty owners list + delete the sole primary owner
        System.runAs(testUser) {
            Test.startTest();
            Map<String, String> result = LeadJointOwnerController.saveOwners(
                lead.Id,
                '[]',
                new List<Id>{ existing.Id }
            );
            Test.stopTest();

            System.assert(result.get('message').contains('Individual'));
        }

        Integer remaining = [
            SELECT COUNT()
            FROM pflexmet__Joint_Owner__c
            WHERE pflexmet__Lead__c = :lead.Id
        ];
        System.assertEquals(0, remaining);

        Lead updatedLead = [
            SELECT pflexmet__Buyer_Type__c FROM Lead WHERE Id = :lead.Id
        ];
        System.assertEquals('Individual', updatedLead.pflexmet__Buyer_Type__c);
    }

    // --------------------------------------------------
    // saveOwners – validation failures
    // --------------------------------------------------

    @IsTest
    static void testSaveOwners_NullLeadId() {
        User testUser = getTestUser();

        System.runAs(testUser) {
            Test.startTest();
            Boolean threw = false;
            try {
                LeadJointOwnerController.saveOwners(null, '[]', null);
            } catch (AuraHandledException e) {
                threw = true;
            }
            Test.stopTest();
            System.assert(threw);
        }
    }

    @IsTest
    static void testSaveOwners_BlankOwnersJson() {
        User testUser = getTestUser();
        Lead lead = getTestLead();

        System.runAs(testUser) {
            Test.startTest();
            Boolean threw = false;
            try {
                LeadJointOwnerController.saveOwners(lead.Id, '', null);
            } catch (AuraHandledException e) {
                threw = true;
            }
            Test.stopTest();
            System.assert(threw);
        }
    }

    @IsTest
    static void testSaveOwners_InvalidJson() {
        User testUser = getTestUser();
        Lead lead = getTestLead();

        System.runAs(testUser) {
            Test.startTest();
            Boolean threw = false;
            try {
                LeadJointOwnerController.saveOwners(
                    lead.Id, 'not-valid-json', null
                );
            } catch (AuraHandledException e) {
                threw = true;
            }
            Test.stopTest();
            System.assert(threw);
        }
    }

    @IsTest
    static void testSaveOwners_MissingContact() {
        User testUser = getTestUser();
        Lead lead = getTestLead();
        String customerType = getValidCustomerType();

        List<Map<String, Object>> rows = new List<Map<String, Object>>{
            new Map<String, Object>{
                'customerType'        => customerType,
                'ownershipOrder'      => 1,
                'ownershipPercentage' => 100,
                'isPrimary'           => true
                // customerContactId omitted
            }
        };

        System.runAs(testUser) {
            Test.startTest();
            Boolean threw = false;
            try {
                LeadJointOwnerController.saveOwners(
                    lead.Id, buildOwnersJson(rows), new List<Id>()
                );
            } catch (AuraHandledException e) {
                threw = true;
            }
            Test.stopTest();
            System.assert(threw, 'Should require a valid Contact');
        }
    }

    @IsTest
    static void testSaveOwners_InvalidCustomerType() {
        User testUser = getTestUser();
        Lead lead = getTestLead();
        Contact con = getTestContacts()[0];

        List<Map<String, Object>> rows = new List<Map<String, Object>>{
            new Map<String, Object>{
                'customerContactId'   => String.valueOf(con.Id),
                'customerType'        => 'NOT_A_REAL_TYPE',
                'ownershipOrder'      => 1,
                'ownershipPercentage' => 100,
                'isPrimary'           => true
            }
        };

        System.runAs(testUser) {
            Test.startTest();
            Boolean threw = false;
            try {
                LeadJointOwnerController.saveOwners(
                    lead.Id, buildOwnersJson(rows), new List<Id>()
                );
            } catch (AuraHandledException e) {
                threw = true;
            }
            Test.stopTest();
            System.assert(threw);
        }
    }

    @IsTest
    static void testSaveOwners_DuplicateOrder() {
        User testUser = getTestUser();
        Lead lead = getTestLead();
        List<Contact> contacts = getTestContacts();
        String customerType = getValidCustomerType();

        List<Map<String, Object>> rows = new List<Map<String, Object>>{
            new Map<String, Object>{
                'customerContactId'   => String.valueOf(contacts[0].Id),
                'customerType'        => customerType,
                'ownershipOrder'      => 1,
                'ownershipPercentage' => 50,
                'isPrimary'           => true
            },
            new Map<String, Object>{
                'customerContactId'   => String.valueOf(contacts[1].Id),
                'customerType'        => customerType,
                'ownershipOrder'      => 1, // duplicate
                'ownershipPercentage' => 50,
                'isPrimary'           => false
            }
        };

        System.runAs(testUser) {
            Test.startTest();
            Boolean threw = false;
            try {
                LeadJointOwnerController.saveOwners(
                    lead.Id, buildOwnersJson(rows), new List<Id>()
                );
            } catch (AuraHandledException e) {
                threw = true;
            }
            Test.stopTest();
            System.assert(threw, 'Should reject duplicate ownership orders');
        }
    }

    @IsTest
    static void testSaveOwners_PercentageNot100() {
        User testUser = getTestUser();
        Lead lead = getTestLead();
        List<Contact> contacts = getTestContacts();
        String customerType = getValidCustomerType();

        List<Map<String, Object>> rows = new List<Map<String, Object>>{
            new Map<String, Object>{
                'customerContactId'   => String.valueOf(contacts[0].Id),
                'customerType'        => customerType,
                'ownershipOrder'      => 1,
                'ownershipPercentage' => 40,
                'isPrimary'           => true
            },
            new Map<String, Object>{
                'customerContactId'   => String.valueOf(contacts[1].Id),
                'customerType'        => customerType,
                'ownershipOrder'      => 2,
                'ownershipPercentage' => 40, // total 80 ≠ 100
                'isPrimary'           => false
            }
        };

        System.runAs(testUser) {
            Test.startTest();
            Boolean threw = false;
            try {
                LeadJointOwnerController.saveOwners(
                    lead.Id, buildOwnersJson(rows), new List<Id>()
                );
            } catch (AuraHandledException e) {
                threw = true;
            }
            Test.stopTest();
            System.assert(threw, 'Percentages must total 100');
        }
    }

    @IsTest
    static void testSaveOwners_NoPrimary() {
        User testUser = getTestUser();
        Lead lead = getTestLead();
        Contact con = getTestContacts()[0];
        String customerType = getValidCustomerType();

        List<Map<String, Object>> rows = new List<Map<String, Object>>{
            new Map<String, Object>{
                'customerContactId'   => String.valueOf(con.Id),
                'customerType'        => customerType,
                'ownershipOrder'      => 1,
                'ownershipPercentage' => 100,
                'isPrimary'           => false
            }
        };

        System.runAs(testUser) {
            Test.startTest();
            Boolean threw = false;
            try {
                LeadJointOwnerController.saveOwners(
                    lead.Id, buildOwnersJson(rows), new List<Id>()
                );
            } catch (AuraHandledException e) {
                threw = true;
            }
            Test.stopTest();
            System.assert(threw, 'Exactly one primary is required');
        }
    }

    @IsTest
    static void testSaveOwners_PrimaryNotOrder1() {
        User testUser = getTestUser();
        Lead lead = getTestLead();
        List<Contact> contacts = getTestContacts();
        String customerType = getValidCustomerType();

        List<Map<String, Object>> rows = new List<Map<String, Object>>{
            new Map<String, Object>{
                'customerContactId'   => String.valueOf(contacts[0].Id),
                'customerType'        => customerType,
                'ownershipOrder'      => 1,
                'ownershipPercentage' => 50,
                'isPrimary'           => false
            },
            new Map<String, Object>{
                'customerContactId'   => String.valueOf(contacts[1].Id),
                'customerType'        => customerType,
                'ownershipOrder'      => 2,
                'ownershipPercentage' => 50,
                'isPrimary'           => true // primary but order 2
            }
        };

        System.runAs(testUser) {
            Test.startTest();
            Boolean threw = false;
            try {
                LeadJointOwnerController.saveOwners(
                    lead.Id, buildOwnersJson(rows), new List<Id>()
                );
            } catch (AuraHandledException e) {
                threw = true;
            }
            Test.stopTest();
            System.assert(threw, 'Primary must have order 1');
        }
    }

    @IsTest
    static void testSaveOwners_PercentageOutOfRange() {
        User testUser = getTestUser();
        Lead lead = getTestLead();
        Contact con = getTestContacts()[0];
        String customerType = getValidCustomerType();

        List<Map<String, Object>> rows = new List<Map<String, Object>>{
            new Map<String, Object>{
                'customerContactId'   => String.valueOf(con.Id),
                'customerType'        => customerType,
                'ownershipOrder'      => 1,
                'ownershipPercentage' => 0, // invalid
                'isPrimary'           => true
            }
        };

        System.runAs(testUser) {
            Test.startTest();
            Boolean threw = false;
            try {
                LeadJointOwnerController.saveOwners(
                    lead.Id, buildOwnersJson(rows), new List<Id>()
                );
            } catch (AuraHandledException e) {
                threw = true;
            }
            Test.stopTest();
            System.assert(threw);
        }
    }

    @IsTest
    static void testSaveOwners_DeleteIdNotOnLead() {
        User testUser = getTestUser();
        Lead lead = getTestLead();
        Contact con = getTestContacts()[0];

        System.runAs(testUser) {
            // Non-setup DML inside runAs avoids MIXED_DML with PermissionSetAssignment
            Lead otherLead = new Lead(
                FirstName = 'Other',
                LastName  = 'Lead',
                Company   = 'Other Co',
                Status    = 'Open - Not Contacted'
            );
            insert otherLead;

            pflexmet__Joint_Owner__c otherOwner = new pflexmet__Joint_Owner__c(
                pflexmet__Lead__c                = otherLead.Id,
                pflexmet__Customer_Name__c       = con.Id,
                pflexmet__Customer_Type__c       = getValidCustomerType(),
                pflexmet__Ownership_Order__c     = 1,
                pflexmet__Percentage_of_Owner__c = 100,
                pflexmet__IsPrimary__c           = true
            );
            insert otherOwner;

            Test.startTest();
            Boolean threw = false;
            try {
                LeadJointOwnerController.saveOwners(
                    lead.Id,
                    '[]',
                    new List<Id>{ otherOwner.Id }
                );
            } catch (AuraHandledException e) {
                threw = true;
            }
            Test.stopTest();
            System.assert(threw, 'Cannot delete owner belonging to another Lead');
        }
    }

    @IsTest
    static void testSaveOwners_EmptyWithNoDeletes() {
        User testUser = getTestUser();
        Lead lead = getTestLead();

        System.runAs(testUser) {
            Test.startTest();
            Boolean threw = false;
            try {
                LeadJointOwnerController.saveOwners(
                    lead.Id, '[]', new List<Id>()
                );
            } catch (AuraHandledException e) {
                threw = true;
            }
            Test.stopTest();
            System.assert(threw, 'Must add or remove at least one owner');
        }
    }
}