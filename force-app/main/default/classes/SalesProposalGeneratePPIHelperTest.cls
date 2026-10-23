@isTest
private class SalesProposalGeneratePPIHelperTest {

    @TestSetup
    static void makeData() {
        // 1. Create Unit
        Units__c testUnit = new Units__c(
            Name = 'Test Unit 101',
            Handover_on__c = Date.today().addDays(365),
            Unit_Price__c = 10000
        );
        insert testUnit;

        // 2. Create Payment Item Masters
        Payment_Item_Master__c mainItem = new Payment_Item_Master__c(
            Name = 'Apartment Price',
            Name__c = 'Apartment Price',
            Main_item__c = true,
            Amount_Percentage__c = 100,
            Type__c = 'Receivable Item'
        );
        
        Payment_Item_Master__c nonMainItem = new Payment_Item_Master__c(
            Name = 'Registration Fee',
            Name__c = 'Registration Fee',
            Main_item__c = false,
            Amount_Percentage__c = 5,
            Type__c = 'Receivable Item'
        );
        insert new List<Payment_Item_Master__c>{ mainItem, nonMainItem };

        // 3. Create Milestone
        Milestone__c testMilestone = new Milestone__c(
            Name = 'Foundation',
            Tentative_Due_Date_of_Completion__c = Date.today().addDays(30)
        );
        insert testMilestone;

        // 4. Create Payment Plan Template
        Payment_Plan_Template__c testTemplate = new Payment_Plan_Template__c(
            Name = 'Standard Plan',
            Status__c = 'Approved'
        );
        insert testTemplate;

        // 5. Create Template Items (Parent and Child)
        Template_Item__c parentItem = new Template_Item__c(
            Payment_Plan_Template__c = testTemplate.Id,
            Item_Name__c = mainItem.Id,
            Percentage__c = 20,
            Payment_Based_On__c = 'Due Days',
            Days__c = 15,
            Order__c = 1
        );
        insert parentItem;

        Template_Item__c childItem = new Template_Item__c(
            Payment_Plan_Template__c = testTemplate.Id,
            Item_Name__c = nonMainItem.Id,
            Percentage__c = 5,
            Payment_Based_On__c = 'Milestone',
            Milestone__c = testMilestone.Id,
            Parent_Template_Item__c = parentItem.Id,
            Order__c = 2
        );
        insert childItem;

        // 6. Create Sales Proposal
        Sales_Proposal__c testProposal = new Sales_Proposal__c(
            Unit__c = testUnit.Id,
            Payment_Plan_Template__c = testTemplate.Id,
            Total_Unit_Price__c = 500000.00
        );
        insert testProposal;
    }

    @isTest
    static void testGeneratePaymentPlanFromProposal() {
        Sales_Proposal__c proposal = [
            SELECT Id, Unit__c, Payment_Plan_Template__c, Total_Unit_Price__c 
            FROM Sales_Proposal__c 
            LIMIT 1
        ];

        Test.startTest();
        SalesProposalGeneratePaymentPlanHelper.generatePaymentPlanFromProposal(new List<Sales_Proposal__c>{ proposal });
        Test.stopTest();

        List<Sales_Proposal_Schedule__c> schedules = [
            SELECT Id, Amount_Due__c, Installment__c, Tentative_Due_Date__c 
            FROM Sales_Proposal_Schedule__c 
            WHERE Sales_Proposal__c = :proposal.Id
        ];

        System.assert(!schedules.isEmpty(), 'Payment plan schedules should be generated successfully.');
    }
}