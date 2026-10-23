public with sharing class SalesProposalGeneratePaymentPlanHelper {
    private class FriendlyLicenseException extends Exception {}

    public class ProposalItemCreationInput {
        public List<Payment_Item_Master__c> mainReceivableItems;
        public List<Payment_Item_Master__c> nonMainReceivableItems;
        public Payment_Item_Master__c apartmentPriceReceivableItems;
        public Sales_Proposal__c proposal;
    }

    public static void generatePaymentPlanFromProposal(List<Sales_Proposal__c> proposalGeneratePaymentPlan) {
        System.debug('Inside SalesProposalGeneratePaymentPlanHelper.generatePaymentPlanFromProposal');

        if (!Test.isRunningTest()) {
            LicenseFacade.LicenseResult res = LicenseFacade.validate(false);
            if (!res.isValid) {
                throw new FriendlyLicenseException(res.message);
            }
        }

        Set<Id> paymentPlanTemplatesIds = new Set<Id>();
        Set<Id> unitIds = new Set<Id>();
        for (Sales_Proposal__c proposal : proposalGeneratePaymentPlan) {
            if (proposal.Payment_Plan_Template__c != null) {
                paymentPlanTemplatesIds.add(proposal.Payment_Plan_Template__c);
            }
            if (proposal.Unit__c != null) {
                unitIds.add(proposal.Unit__c);
            }
        }

        List<Template_Item__c> templateItems = [
            SELECT
                Id,
                Item_Name__c,
                Payment_Plan_Template__c,
                Days__c,
                Percentage__c,
                Payment_Item_Master__c,
                Payment_Item_Master__r.Name,
                Payment_Based_On__c,
                Milestone__c,
                Order__c,
                Tentative_Due_Date__c,
                Milestone__r.Tentative_Due_Date_of_Completion__c,
                Milestone__r.Actual_Date_of_Completion__c
            FROM Template_Item__c
            WHERE Payment_Plan_Template__c IN :paymentPlanTemplatesIds
        ];

        Set<Id> templateItemIds = new Set<Id>();
        for (Template_Item__c templateItem : templateItems) {
            templateItemIds.add(templateItem.Id);
        }

        List<Template_Item__c> parentTemplateItem = [
            SELECT
                Id,
                Item_Name__c,
                Payment_Plan_Template__c,
                Days__c,
                Percentage__c,
                Payment_Item_Master__c,
                Payment_Item_Master__r.Name,
                Payment_Based_On__c,
                Milestone__c,
                Order__c,
                Tentative_Due_Date__c,
                Milestone__r.Tentative_Due_Date_of_Completion__c,
                Milestone__r.Actual_Date_of_Completion__c,
                Parent_Template_Item__c
            FROM Template_Item__c
            WHERE Parent_Template_Item__c IN :templateItemIds
        ];

        Map<Id, List<Template_Item__c>> childTemplateItemMap = new Map<Id, List<Template_Item__c>>();
        for (Template_Item__c templateItem : parentTemplateItem) {
            if (childTemplateItemMap.containsKey(templateItem.Parent_Template_Item__c)) {
                childTemplateItemMap.get(templateItem.Parent_Template_Item__c).add(templateItem);
            } else {
                childTemplateItemMap.put(templateItem.Parent_Template_Item__c, new List<Template_Item__c>{ templateItem });
            }
        }

        List<Units__c> unitsList = [
            SELECT Id, Handover_on__c
            FROM Units__c
            WHERE Id IN :unitIds
        ];
        Map<Id, Units__c> unitMap = new Map<Id, Units__c>();
        for (Units__c unit : unitsList) {
            unitMap.put(unit.Id, unit);
        }

        Map<Id, Units__c> proposalIdUnitMap = new Map<Id, Units__c>();
        for (Sales_Proposal__c proposal : proposalGeneratePaymentPlan) {
            if (proposal.Unit__c != null && unitMap.containsKey(proposal.Unit__c)) {
                proposalIdUnitMap.put(proposal.Id, unitMap.get(proposal.Unit__c));
            }
        }

        Map<Id, List<Template_Item__c>> paymentPlanTemplateTemplateItemMap = new Map<Id, List<Template_Item__c>>();
        Map<Id, Date> milestoneDateMap = new Map<Id, Date>();
        for (Template_Item__c templateItem : templateItems) {
            if (!paymentPlanTemplateTemplateItemMap.containsKey(templateItem.Payment_Plan_Template__c)) {
                paymentPlanTemplateTemplateItemMap.put(templateItem.Payment_Plan_Template__c, new List<Template_Item__c>());
            }
            if (templateItem.Milestone__c != null && !milestoneDateMap.containsKey(templateItem.Milestone__c)) {
                if (templateItem.Milestone__r.Actual_Date_of_Completion__c != null) {
                    milestoneDateMap.put(templateItem.Milestone__c, templateItem.Milestone__r.Actual_Date_of_Completion__c);
                } else if (templateItem.Milestone__r.Tentative_Due_Date_of_Completion__c != null) {
                    milestoneDateMap.put(templateItem.Milestone__c, templateItem.Milestone__r.Tentative_Due_Date_of_Completion__c);
                }
            }
            paymentPlanTemplateTemplateItemMap.get(templateItem.Payment_Plan_Template__c).add(templateItem);
        }

        Map<Sales_Proposal__c, List<Template_Item__c>> proposalTemplateItemMap = new Map<Sales_Proposal__c, List<Template_Item__c>>();
        Map<Sales_Proposal__c, Set<Id>> proposalPaymentItemMasterIdsMap = new Map<Sales_Proposal__c, Set<Id>>();
        
        for (Sales_Proposal__c proposal : proposalGeneratePaymentPlan) {
            List<Template_Item__c> templateItemList = new List<Template_Item__c>();
            if (proposal.Payment_Plan_Template__c != null && paymentPlanTemplateTemplateItemMap.containsKey(proposal.Payment_Plan_Template__c)) {
                templateItemList.addAll(paymentPlanTemplateTemplateItemMap.get(proposal.Payment_Plan_Template__c));
            }
            proposalTemplateItemMap.put(proposal, templateItemList);

            Set<Id> masterIds = new Set<Id>();
            for (Template_Item__c templateItem : templateItemList) {
                masterIds.add(templateItem.Item_Name__c);
            }
            proposalPaymentItemMasterIdsMap.put(proposal, masterIds);
        }

        if (!proposalTemplateItemMap.isEmpty()) {
            generateProposalPaymentPlanInternal(
                proposalTemplateItemMap,
                proposalPaymentItemMasterIdsMap,
                milestoneDateMap,
                proposalIdUnitMap,
                childTemplateItemMap
            );
        }
    }

    private static void generateProposalPaymentPlanInternal(
        Map<Sales_Proposal__c, List<Template_Item__c>> proposalTemplateItemMap,
        Map<Sales_Proposal__c, Set<Id>> proposalPaymentItemMasterIdsMap,
        Map<Id, Date> milestoneDateMap,
        Map<Id, Units__c> proposalIdUnitMap,
        Map<Id, List<Template_Item__c>> childTemplateItemMap
    ) {
        Set<Id> paymentItemMasterIds = new Set<Id>();
        for (Sales_Proposal__c proposal : proposalTemplateItemMap.keySet()) {
            List<Template_Item__c> templateItems = proposalTemplateItemMap.get(proposal);
            if (templateItems != null) {
                for (Template_Item__c templateItem : templateItems) {
                    paymentItemMasterIds.add(templateItem.Item_Name__c);
                }
            }
        }

        List<Payment_Item_Master__c> paymentItemMasters = [
            SELECT
                Id,
                Added_To_Total_Deal_Value__c,
                Amount_Field__c,
                Amount_Percentage__c,
                Category__c,
                Display_Order__c,
                Main_item__c,
                Name__c,
                Name,
                Object_Name__c,
                Payment_Type__c,
                Type__c,
                Tax_Applicable_From__c,
                Tax_Code__c,
                Tax_Code__r.Tax_Percentage__c
            FROM Payment_Item_Master__c
            WHERE Id IN :paymentItemMasterIds
        ];

        Map<Id, Payment_Item_Master__c> paymentItemMastersMap = new Map<Id, Payment_Item_Master__c>();
        for (Payment_Item_Master__c pim : paymentItemMasters) {
            paymentItemMastersMap.put(pim.Id, pim);
        }

        List<ProposalItemCreationInput> proposalItemCreationInputs = new List<ProposalItemCreationInput>();
        for (Sales_Proposal__c proposal : proposalTemplateItemMap.keySet()) {
            ProposalItemCreationInput input = new ProposalItemCreationInput();
            input.proposal = proposal;
            input.nonMainReceivableItems = new List<Payment_Item_Master__c>();
            input.apartmentPriceReceivableItems = new Payment_Item_Master__c();
            input.mainReceivableItems = new List<Payment_Item_Master__c>();

            Set<Id> masterIds = proposalPaymentItemMasterIdsMap.get(proposal);
            if (masterIds != null) {
                for (Id masterId : masterIds) {
                    Payment_Item_Master__c paymentItemMaster = paymentItemMastersMap.get(masterId);
                    if (paymentItemMaster != null) {
                        if (paymentItemMaster.Main_item__c == false) {
                            input.nonMainReceivableItems.add(paymentItemMaster);
                        } else {
                            if (paymentItemMaster.Name__c == 'Apartment Price' || paymentItemMaster.Name == 'Apartment Price') {
                                input.apartmentPriceReceivableItems = paymentItemMaster;
                            } else {
                                input.mainReceivableItems.add(paymentItemMaster);
                            }
                        }
                    }
                }
            }
            proposalItemCreationInputs.add(input);
        }

        createProposalItem(
            proposalItemCreationInputs,
            proposalTemplateItemMap,
            milestoneDateMap,
            proposalIdUnitMap,
            childTemplateItemMap
        );
    }

    public static void createProposalItem(
        List<ProposalItemCreationInput> proposalItemCreationInputs,
        Map<Sales_Proposal__c, List<Template_Item__c>> proposalTemplateItemMap,
        Map<Id, Date> milestoneDateMap,
        Map<Id, Units__c> proposalIdUnitMap,
        Map<Id, List<Template_Item__c>> childTemplateItemMap
    ) {
        List<Sales_Proposal_Schedule_Master__c> newProposalMasters = new List<Sales_Proposal_Schedule_Master__c>();

        for (ProposalItemCreationInput proposalSet : proposalItemCreationInputs) {
            Id proposalId = proposalSet.proposal.Id;
            Id unitId = proposalSet.proposal.Unit__c;
            Decimal proposalUnitPrice = proposalSet.proposal.Total_Unit_Price__c != null ? proposalSet.proposal.Total_Unit_Price__c : 0;
            Decimal taxPercentage = 5.0;
            Decimal nonMainTotalPercentage = 0;

            // 1. Process Non-Main Receivable Items
            if (proposalSet.nonMainReceivableItems != null) {
                for (Payment_Item_Master__c receivableItem : proposalSet.nonMainReceivableItems) {
                    Decimal percentage = receivableItem.Amount_Percentage__c != null ? receivableItem.Amount_Percentage__c : 0;
                    nonMainTotalPercentage += percentage;
                    Decimal amountValue = proposalUnitPrice * (percentage / 100);
                    Decimal totalAmount = amountValue;

                    Sales_Proposal_Schedule_Master__c newMaster = new Sales_Proposal_Schedule_Master__c();
                    newMaster.Sales_Proposal__c = proposalId;
                    newMaster.Units__c = unitId;
                    newMaster.Amount__c = totalAmount.setScale(2).round(System.RoundingMode.CEILING);
                   // newMaster.Name = receivableItem.Name__c != null ? receivableItem.Name__c : receivableItem.Name;
                   // newMaster.Status__c = 'New';
                    newProposalMasters.add(newMaster);
                }
            }

            // 2. Process Apartment Price Receivable Items
            if (proposalSet.apartmentPriceReceivableItems != null && proposalSet.apartmentPriceReceivableItems.Id != null) {
                Payment_Item_Master__c receivableItem = proposalSet.apartmentPriceReceivableItems;
                Decimal basePercentage = receivableItem.Amount_Percentage__c != null ? receivableItem.Amount_Percentage__c : 100;
                Decimal percentage = basePercentage - nonMainTotalPercentage;

                Decimal amountValue = proposalUnitPrice * (percentage / 100);
                Decimal totalAmount = amountValue;

                Sales_Proposal_Schedule_Master__c newMaster = new Sales_Proposal_Schedule_Master__c();
                newMaster.Sales_Proposal__c = proposalId;
                newMaster.Units__c = unitId;
                newMaster.Amount__c = totalAmount.setScale(2).round(System.RoundingMode.CEILING);
              //  newMaster.Name = receivableItem.Name__c != null ? receivableItem.Name__c : receivableItem.Name;
                newMaster.Status__c = 'Active';
                newProposalMasters.add(newMaster);
            }

            // 3. Process Main Receivable Items
            if (proposalSet.mainReceivableItems != null) {
                for (Payment_Item_Master__c receivableItem : proposalSet.mainReceivableItems) {
                    Decimal percentage = receivableItem.Amount_Percentage__c != null ? receivableItem.Amount_Percentage__c : 0;
                    Decimal amountValue = proposalUnitPrice * (percentage / 100);
                    Decimal totalAmount = amountValue;

                    Sales_Proposal_Schedule_Master__c newMaster = new Sales_Proposal_Schedule_Master__c();
                    newMaster.Sales_Proposal__c = proposalId;
                    newMaster.Units__c = unitId;
                    newMaster.Amount__c = totalAmount.setScale(2).round(System.RoundingMode.CEILING);
                   // newMaster.Name = receivableItem.Name__c != null ? receivableItem.Name__c : receivableItem.Name;
                    newMaster.Status__c = 'Active';
                    newProposalMasters.add(newMaster);
                }
            }
        }

        if (!newProposalMasters.isEmpty()) {
            insert newProposalMasters;
            proposalPaymentPlanItemsGeneration(
                newProposalMasters,
                proposalTemplateItemMap,
                milestoneDateMap,
                proposalIdUnitMap,
                childTemplateItemMap
            );
        }
    }

   private static void proposalPaymentPlanItemsGeneration(
        List<Sales_Proposal_Schedule_Master__c> newProposalMasters,
        Map<Sales_Proposal__c, List<Template_Item__c>> proposalTemplateItemMap,
        Map<Id, Date> milestoneDateMap,
        Map<Id, Units__c> proposalIdUnitMap,
        Map<Id, List<Template_Item__c>> childTemplateItemMap
    ) {
        System.debug('Inside SalesProposalPaymentPlanHelper.proposalPaymentPlanItemsGeneration');

        Map<Id, Set<Sales_Proposal_Schedule_Master__c>> proposalIdMasterMap = new Map<Id, Set<Sales_Proposal_Schedule_Master__c>>();
        for (Sales_Proposal_Schedule_Master__c masterItem : newProposalMasters) {
            if (!proposalIdMasterMap.containsKey(masterItem.Sales_Proposal__c)) {
                proposalIdMasterMap.put(masterItem.Sales_Proposal__c, new Set<Sales_Proposal_Schedule_Master__c>());
            }
            proposalIdMasterMap.get(masterItem.Sales_Proposal__c).add(masterItem);
        }

        Map<Id, List<Template_Item__c>> proposalIdTemplateItemMap = new Map<Id, List<Template_Item__c>>();
        for (Sales_Proposal__c proposal : proposalTemplateItemMap.keySet()) {
            proposalIdTemplateItemMap.put(proposal.Id, proposalTemplateItemMap.get(proposal));
        }

        Map<Sales_Proposal_Schedule_Master__c, List<Template_Item__c>> masterTemplateItemMap = new Map<Sales_Proposal_Schedule_Master__c, List<Template_Item__c>>();
        for (Id proposalId : proposalIdMasterMap.keySet()) {
            Set<Sales_Proposal_Schedule_Master__c> masters = proposalIdMasterMap.get(proposalId);
            List<Template_Item__c> templateItems = proposalIdTemplateItemMap.get(proposalId);

            if (masters != null && templateItems != null) {
                for (Sales_Proposal_Schedule_Master__c master : masters) {
                    for (Template_Item__c templateItem : templateItems) {
                        if (!masterTemplateItemMap.containsKey(master)) {
                            masterTemplateItemMap.put(master, new List<Template_Item__c>());
                        }
                        masterTemplateItemMap.get(master).add(templateItem);
                    }
                }
            }
        }

        List<Sales_Proposal_Schedule__c> proposalSchedules = new List<Sales_Proposal_Schedule__c>();

        for (Sales_Proposal_Schedule_Master__c master : masterTemplateItemMap.keySet()) {
            List<Template_Item__c> templateItemsList = masterTemplateItemMap.get(master);
            for (Template_Item__c templateItem : templateItemsList) {
                
                // 1. Parent Template Item Schedule Row
                Sales_Proposal_Schedule__c schedule = new Sales_Proposal_Schedule__c();
                schedule.Sales_Proposal__c = master.Sales_Proposal__c;
                schedule.Sales_Proposal_Schedule_Master__c = master.Id;
                schedule.Unit__c = master.Units__c;
                schedule.Payment_Plan_Template__c = templateItem.Payment_Plan_Template__c;
                schedule.Milestone__c = templateItem.Milestone__c;
                schedule.Status__c = 'Active';
                
                Decimal percentage = templateItem.Percentage__c != null ? templateItem.Percentage__c : 0;
                Decimal amount = master.Amount__c != null ? master.Amount__c * (percentage / 100) : 0;
                schedule.Amount_Due__c = amount.setScale(2);
                
                if (templateItem.Payment_Item_Master__r != null) {
                    schedule.Installment__c = templateItem.Payment_Item_Master__r.Name;
                }

                // Tentative_Due_Date__c calculation based on payment trigger type
                if (templateItem.Payment_Based_On__c == 'Milestone' && milestoneDateMap.containsKey(templateItem.Milestone__c)) {
                    schedule.Tentative_Due_Date__c = milestoneDateMap.get(templateItem.Milestone__c);
                } else if (templateItem.Payment_Based_On__c == 'Due Days' && templateItem.Days__c != null) {
                    schedule.Tentative_Due_Date__c = Date.today().addDays(Integer.valueOf(templateItem.Days__c));
                } else if (templateItem.Payment_Based_On__c == 'Due date') {
                    schedule.Tentative_Due_Date__c = templateItem.Tentative_Due_Date__c;
                } else if (templateItem.Payment_Based_On__c == 'Post Date Handover') {
                    Units__c u = proposalIdUnitMap.get(master.Sales_Proposal__c);
                    if (u != null && u.Handover_on__c != null && templateItem.Days__c != null) {
                        schedule.Tentative_Due_Date__c = u.Handover_on__c.addDays(Integer.valueOf(templateItem.Days__c));
                    }
                }
                proposalSchedules.add(schedule);

                // 2. Child Template Items Processing (if any)
                if (childTemplateItemMap.containsKey(templateItem.Id)) {
                    for (Template_Item__c childTemplateItem : childTemplateItemMap.get(templateItem.Id)) {
                        Sales_Proposal_Schedule__c childSchedule = new Sales_Proposal_Schedule__c();
                        childSchedule.Sales_Proposal__c = master.Sales_Proposal__c;
                        childSchedule.Sales_Proposal_Schedule_Master__c = master.Id;                       
                        childSchedule.Unit__c = master.Units__c;
                        childSchedule.Payment_Plan_Template__c = childTemplateItem.Payment_Plan_Template__c;
                        childSchedule.Milestone__c = childTemplateItem.Milestone__c;
                        childSchedule.Status__c = 'Active';

                        if (childTemplateItem.Payment_Item_Master__r != null) {
                            childSchedule.Installment__c = childTemplateItem.Payment_Item_Master__r.Name;
                        }

                        // Child Tentative Due Date calculation logic
                        if (templateItem.Payment_Based_On__c == 'Milestone' && milestoneDateMap.containsKey(childTemplateItem.Milestone__c)) {
                            childSchedule.Tentative_Due_Date__c = milestoneDateMap.get(childTemplateItem.Milestone__c);
                        } else if (templateItem.Payment_Based_On__c == 'Due Days' && childTemplateItem.Days__c != null) {
                            childSchedule.Tentative_Due_Date__c = Date.today().addDays(Integer.valueOf(childTemplateItem.Days__c));
                        } else if (templateItem.Payment_Based_On__c == 'Due date') {
                            childSchedule.Tentative_Due_Date__c = childTemplateItem.Tentative_Due_Date__c;
                        } else if (templateItem.Payment_Based_On__c == 'Post Date Handover') {
                            Units__c u = proposalIdUnitMap.get(master.Sales_Proposal__c);
                            if (u != null && u.Handover_on__c != null && childTemplateItem.Days__c != null) {
                                childSchedule.Tentative_Due_Date__c = u.Handover_on__c.addDays(Integer.valueOf(childTemplateItem.Days__c));
                            }
                        }
                        proposalSchedules.add(childSchedule);
                    }
                }

            }
        }

        if (!proposalSchedules.isEmpty()) {
            insert proposalSchedules;
        }
    }
}