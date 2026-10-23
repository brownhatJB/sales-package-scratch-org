/**
 * @module            : Real_Estate_Module
 * @description       :
 * @namespace         :
 * @author            : SREERAM.R
 * @group             :
 * @last modified on  : 23-10-2026
 * @last modified by  : Jouhar C
 **/
public with sharing class MilestoneTriggerUpdate implements TriggerAction.AfterUpdate {

  public void afterUpdate(
    List<Milestone__c> newMilestones,
    List<Milestone__c> oldMilestones
  ) {
    Map<Id, Milestone__c> oldMilestoneMap = new Map<Id, Milestone__c>();
    for (Milestone__c milestone : oldMilestones) {
      oldMilestoneMap.put(milestone.Id, milestone);
    }
    Map<Id, Milestone__c> newMilestoneMap = new Map<Id, Milestone__c>();
    for (Milestone__c milestone : newMilestones) {
      newMilestoneMap.put(milestone.Id, milestone);
    }

    List<Milestone__c> actualDueDateChangedMilestone = new List<Milestone__c>();
    List<Milestone__c> tentativeDueDateChangedMilestone = new List<Milestone__c>();
    List<Milestone__c> commentChangedMilestones = new List<Milestone__c>();

    for (Milestone__c milestone : newMilestones) {
      Milestone__c oldMilestone = oldMilestoneMap.get(milestone.Id);

      if (milestone.Actual_Date_of_Completion__c != oldMilestone.Actual_Date_of_Completion__c) {
        actualDueDateChangedMilestone.add(milestone);
      }
      if (milestone.Tentative_Due_Date_of_Completion__c != oldMilestone.Tentative_Due_Date_of_Completion__c) {
        tentativeDueDateChangedMilestone.add(milestone);
      }
      if (milestone.Comments__c != oldMilestone.Comments__c) {
        Milestone__c milestoneToUpdate = new Milestone__c(Id = milestone.Id);
        milestoneToUpdate.Milestone_Comment_change_flag__c = true;
        commentChangedMilestones.add(milestoneToUpdate);
      }
    }

    if (!commentChangedMilestones.isEmpty()) {
      update commentChangedMilestones;
    }

    if (!actualDueDateChangedMilestone.isEmpty()) {
      Map<Milestone__c, List<Payment_Plan_Item__c>> actualDueDateChangedMilestoneMap =
        createMilestonePaymentPlanItemMap(actualDueDateChangedMilestone, newMilestoneMap);
      updateActualDueDateChangedMilestonePaymentPlanItems(actualDueDateChangedMilestoneMap);

      Map<Milestone__c, List<Offer_Payment_Plan_Item__c>> actualDueDateChangedMilestoneOfferMap =
        createMilestoneOfferPaymentPlanItemMap(actualDueDateChangedMilestone, newMilestoneMap);
      updateActualDueDateChangedMilestoneOfferPaymentPlanItems(actualDueDateChangedMilestoneOfferMap);
    }

    if (!tentativeDueDateChangedMilestone.isEmpty()) {
      Map<Milestone__c, List<Payment_Plan_Item__c>> tentativeDueDateChangedMilestoneMap =
        createMilestonePaymentPlanItemMap(tentativeDueDateChangedMilestone, newMilestoneMap);
      updateTentativeDueDateChangedMilestonePaymentPlanItems(tentativeDueDateChangedMilestoneMap);

      Map<Milestone__c, List<Offer_Payment_Plan_Item__c>> tentativeDueDateChangedMilestoneOfferMap =
        createMilestoneOfferPaymentPlanItemMap(tentativeDueDateChangedMilestone, newMilestoneMap);
      updateTentativeDueDateChangedMilestoneOfferPaymentPlanItems(tentativeDueDateChangedMilestoneOfferMap);
    }
  }

  // ----- helper methods stay exactly as you already have them -----
  private Map<Milestone__c, List<Payment_Plan_Item__c>> createMilestonePaymentPlanItemMap(
    List<Milestone__c> milestones,
    Map<ID, SObject> newMilestoneMap
  ) {
    List<ID> milestoneIds = new List<ID>();
    for (Milestone__c milestone : milestones) {
      milestoneIds.add(milestone.Id);
    }
    List<Payment_Plan_Item__c> paymentPlanItems = [
      SELECT Id, Milestone__c, Proposed_Due_Date__c, Actual_Due_Date__c, Status__c
      FROM Payment_Plan_Item__c
      WHERE Milestone__c IN :milestoneIds AND Status__c = 'Not Invoiced'
      WITH USER_MODE
    ];
    Map<Milestone__c, List<Payment_Plan_Item__c>> milestonePaymentPlanItemMap =
      new Map<Milestone__c, List<Payment_Plan_Item__c>>();
    for (Payment_Plan_Item__c paymentPlanItem : paymentPlanItems) {
      Milestone__c milestone = (Milestone__c) newMilestoneMap.get(paymentPlanItem.Milestone__c);
      if (!milestonePaymentPlanItemMap.containsKey(milestone)) {
        milestonePaymentPlanItemMap.put(milestone, new List<Payment_Plan_Item__c>());
      }
      milestonePaymentPlanItemMap.get(milestone).add(paymentPlanItem);
    }
    return milestonePaymentPlanItemMap;
  }

  private Map<Milestone__c, List<Offer_Payment_Plan_Item__c>> createMilestoneOfferPaymentPlanItemMap(
    List<Milestone__c> milestones,
    Map<ID, SObject> newMilestoneMap
  ) {
    List<ID> milestoneIds = new List<ID>();
    for (Milestone__c milestone : milestones) {
      milestoneIds.add(milestone.Id);
    }
    List<Offer_Payment_Plan_Item__c> OfferPaymentPlanItems = [
      SELECT Id, Milestone__c, Tentative_Due_Date__c, Status__c
      FROM Offer_Payment_Plan_Item__c
      WHERE Milestone__c IN :milestoneIds AND Offer__r.Unit_Sale__c = null
      WITH USER_MODE
    ];
    Map<Milestone__c, List<Offer_Payment_Plan_Item__c>> milestoneOfferPaymentPlanItemMap =
      new Map<Milestone__c, List<Offer_Payment_Plan_Item__c>>();
    for (Offer_Payment_Plan_Item__c offerPaymentPlanItem : OfferPaymentPlanItems) {
      Milestone__c milestone = (Milestone__c) newMilestoneMap.get(offerPaymentPlanItem.Milestone__c);
      if (!milestoneOfferPaymentPlanItemMap.containsKey(milestone)) {
        milestoneOfferPaymentPlanItemMap.put(milestone, new List<Offer_Payment_Plan_Item__c>());
      }
      milestoneOfferPaymentPlanItemMap.get(milestone).add(offerPaymentPlanItem);
    }
    return milestoneOfferPaymentPlanItemMap;
  }

  private static void updateActualDueDateChangedMilestonePaymentPlanItems(
    Map<Milestone__c, List<Payment_Plan_Item__c>> actualDueDateChangedMilestoneMap
  ) {
    List<Payment_Plan_Item__c> paymentPlanItems = new List<Payment_Plan_Item__c>();
    List<Milestone__c> milestonesToUpdate = new List<Milestone__c>();

    for (Milestone__c milestone : actualDueDateChangedMilestoneMap.keySet()) {
      for (Payment_Plan_Item__c paymentPlanItem : actualDueDateChangedMilestoneMap.get(milestone)) {
        paymentPlanItem.Actual_Due_Date__c = milestone.Actual_Date_of_Completion__c;
        paymentPlanItems.add(paymentPlanItem);
      }
      milestonesToUpdate.add(milestone);
    }
    update paymentPlanItems;

    if (!milestonesToUpdate.isEmpty()) {
      Set<Id> milestoneIds = new Set<Id>();
      for (Milestone__c milestone : milestonesToUpdate) {
        milestoneIds.add(milestone.Id);
      }
      List<Milestone__c> milestonesForUpdate = [
        SELECT Id, Milestone_Trigger_Flag__c
        FROM Milestone__c
        WHERE Id IN :milestoneIds
      ];
      for (Milestone__c milestone : milestonesForUpdate) {
        milestone.Milestone_Trigger_Flag__c = false;
      }
      update milestonesForUpdate;
    }
  }

  private static void updateTentativeDueDateChangedMilestonePaymentPlanItems(
    Map<Milestone__c, List<Payment_Plan_Item__c>> tentativeDueDateChangedMilestoneMap
  ) {
    List<Payment_Plan_Item__c> paymentPlanItems = new List<Payment_Plan_Item__c>();
    for (Milestone__c milestone : tentativeDueDateChangedMilestoneMap.keySet()) {
      for (Payment_Plan_Item__c paymentPlanItem : tentativeDueDateChangedMilestoneMap.get(milestone)) {
        paymentPlanItem.Actual_Due_Date__c = milestone.Tentative_Due_Date_of_Completion__c;
        paymentPlanItems.add(paymentPlanItem);
      }
    }
    update paymentPlanItems;
  }

  private static void updateActualDueDateChangedMilestoneOfferPaymentPlanItems(
    Map<Milestone__c, List<Offer_Payment_Plan_Item__c>> actualDueDateChangedMilestoneMap
  ) {
    List<Offer_Payment_Plan_Item__c> paymentPlanItems = new List<Offer_Payment_Plan_Item__c>();
    List<Milestone__c> milestonesToUpdate = new List<Milestone__c>();

    for (Milestone__c milestone : actualDueDateChangedMilestoneMap.keySet()) {
      for (Offer_Payment_Plan_Item__c paymentPlanItem : actualDueDateChangedMilestoneMap.get(milestone)) {
        paymentPlanItem.Tentative_Due_Date__c = milestone.Actual_Date_of_Completion__c;
        paymentPlanItems.add(paymentPlanItem);
      }
      milestonesToUpdate.add(milestone);
    }
    update paymentPlanItems;

    if (!milestonesToUpdate.isEmpty()) {
      Set<Id> milestoneIds = new Set<Id>();
      for (Milestone__c milestone : milestonesToUpdate) {
        milestoneIds.add(milestone.Id);
      }
      List<Milestone__c> milestonesForUpdate = [
        SELECT Id, Milestone_Trigger_Flag__c
        FROM Milestone__c
        WHERE Id IN :milestoneIds
      ];
      for (Milestone__c milestone : milestonesForUpdate) {
        milestone.Milestone_Trigger_Flag__c = false;
      }
      update milestonesForUpdate;
    }
  }

  private static void updateTentativeDueDateChangedMilestoneOfferPaymentPlanItems(
    Map<Milestone__c, List<Offer_Payment_Plan_Item__c>> tentativeDueDateChangedMilestoneMap
  ) {
    List<Offer_Payment_Plan_Item__c> paymentPlanItems = new List<Offer_Payment_Plan_Item__c>();
    for (Milestone__c milestone : tentativeDueDateChangedMilestoneMap.keySet()) {
      for (Offer_Payment_Plan_Item__c paymentPlanItem : tentativeDueDateChangedMilestoneMap.get(milestone)) {
        paymentPlanItem.Tentative_Due_Date__c = milestone.Tentative_Due_Date_of_Completion__c;
        paymentPlanItems.add(paymentPlanItem);
      }
    }
    update paymentPlanItems;
  }
}