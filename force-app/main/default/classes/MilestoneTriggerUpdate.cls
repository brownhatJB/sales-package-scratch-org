/**
 * @module            : Real_Estate_Module
 * @description       :
 * @namespace         :
 * @author            : SREERAM.R
 * @group             :
 * @last modified on  : 01-05-2026
 * @last modified by  : SREERAM.R
 **/
public with sharing class MilestoneTriggerUpdate implements TriggerAction.AfterUpdate {
  	/*	
     public void afterUpdate(List<Milestone__c> newMilestones, List<Milestone__c> oldMilestones) {
        // Create maps to track old milestone data
        Map<Id, Milestone__c> oldMilestoneMap = new Map<Id, Milestone__c>();
        for (Milestone__c milestone : oldMilestones) {
            oldMilestoneMap.put(milestone.Id, milestone);
        }

        // Lists to store milestones that require updates
        List<Milestone__c> milestonesToUpdate = new List<Milestone__c>();
        List<Milestone__c> actualDueDateChangedMilestone = new List<Milestone__c>();
        List<Milestone__c> tentativeDueDateChangedMilestone = new List<Milestone__c>();

        // Loop through new milestones and check the trigger flag
        for (Milestone__c milestone : newMilestones) {
            Milestone__c oldMilestone = oldMilestoneMap.get(milestone.Id);

            // **Proceed only if the Milestone_Trigger_Flag is set to true**
            if (milestone.Milestone_Trigger_Flag__c == true &&
                oldMilestone.Milestone_Trigger_Flag__c == false) { // flag changed from false to true

                // Track Actual Due Date change
                if (milestone.Actual_Date_of_Completion__c != oldMilestone.Actual_Date_of_Completion__c) {
                    actualDueDateChangedMilestone.add(milestone);
                }

                // Track Tentative Due Date change
                if (milestone.Tentative_Due_Date_of_Completion__c != oldMilestone.Tentative_Due_Date_of_Completion__c) {
                    tentativeDueDateChangedMilestone.add(milestone);
                }

                // Track comment changes
                if (milestone.Comments__c != oldMilestone.Comments__c) {
                   // setCommentChangeFlag(milestone, oldMilestone, milestonesToUpdate);
                }
            }
        }

        // Update milestones where the comment changed
        if (!milestonesToUpdate.isEmpty()) {
            update milestonesToUpdate; // Perform DML update
        }

        // Update actual due date changed milestones
        if (!actualDueDateChangedMilestone.isEmpty()) {
            Map<Milestone__c, List<Payment_Plan_Item__c>> actualDueDateChangedMilestoneMap =
                createMilestonePaymentPlanItemMap(actualDueDateChangedMilestone, oldMilestoneMap);
            updateActualDueDateChangedMilestonePaymentPlanItems(actualDueDateChangedMilestoneMap, milestonesToUpdate);
        }

        // Update tentative due date changed milestones
        if (!tentativeDueDateChangedMilestone.isEmpty()) {
            Map<Milestone__c, List<Payment_Plan_Item__c>> tentativeDueDateChangedMilestoneMap =
                createMilestonePaymentPlanItemMap(tentativeDueDateChangedMilestone, oldMilestoneMap);
            updateTentativeDueDateChangedMilestonePaymentPlanItems(tentativeDueDateChangedMilestoneMap, milestonesToUpdate);
        }

        // Update the milestones to reset the Trigger Flag
        if (!milestonesToUpdate.isEmpty()) {
            update milestonesToUpdate; // Perform DML update for resetting the flag
        }
    }

    // Method to map milestones to payment plan items
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
        Map<Milestone__c, List<Payment_Plan_Item__c>> milestonePaymentPlanItemMap = new Map<Milestone__c, List<Payment_Plan_Item__c>>();
        for (Payment_Plan_Item__c paymentPlanItem : paymentPlanItems) {
            Milestone__c milestone = (Milestone__c) newMilestoneMap.get(paymentPlanItem.Milestone__c);
            if (!milestonePaymentPlanItemMap.containsKey(milestone)) {
                milestonePaymentPlanItemMap.put(milestone, new List<Payment_Plan_Item__c>());
            }
            milestonePaymentPlanItemMap.get(milestone).add(paymentPlanItem);
        }
        return milestonePaymentPlanItemMap;
    }

    // Method to update actual due date changed milestones
    private static void updateActualDueDateChangedMilestonePaymentPlanItems(
        Map<Milestone__c, List<Payment_Plan_Item__c>> actualDueDateChangedMilestoneMap,
        List<Milestone__c> milestonesToUpdate // pass the list here
    ) {
        List<Payment_Plan_Item__c> paymentPlanItems = new List<Payment_Plan_Item__c>();

        for (Milestone__c milestone : actualDueDateChangedMilestoneMap.keySet()) {
            for (Payment_Plan_Item__c paymentPlanItem : actualDueDateChangedMilestoneMap.get(milestone)) {
                paymentPlanItem.Actual_Due_Date__c = milestone.Actual_Date_of_Completion__c;
                paymentPlanItems.add(paymentPlanItem);
            }
            // **Set the Milestone Trigger Flag back to false**
            milestone.Milestone_Trigger_Flag__c = false;
            milestonesToUpdate.add(milestone); // Add to update list
        }
        update paymentPlanItems; // DML to update payment plan items
    }

    // Method to update tentative due date changed milestones
    private static void updateTentativeDueDateChangedMilestonePaymentPlanItems(
        Map<Milestone__c, List<Payment_Plan_Item__c>> tentativeDueDateChangedMilestoneMap,
        List<Milestone__c> milestonesToUpdate // pass the list here
    ) {
        List<Payment_Plan_Item__c> paymentPlanItems = new List<Payment_Plan_Item__c>();

        for (Milestone__c milestone : tentativeDueDateChangedMilestoneMap.keySet()) {
            for (Payment_Plan_Item__c paymentPlanItem : tentativeDueDateChangedMilestoneMap.get(milestone)) {
                paymentPlanItem.Actual_Due_Date__c = milestone.Tentative_Due_Date_of_Completion__c;
                paymentPlanItems.add(paymentPlanItem);
            }
            // **Set the Milestone Trigger Flag back to false**
            milestone.Milestone_Trigger_Flag__c = false;
            milestonesToUpdate.add(milestone); // Add to update list
        }
        update paymentPlanItems; // DML to update payment plan items
    }

    // Private method to set the comment change flag
    private void setCommentChangeFlag(Milestone__c milestone, Milestone__c oldMilestone, List<Milestone__c> milestonesToUpdate) {
        if (milestone.Comments__c != oldMilestone.Comments__c) {
            milestone.Milestone_Comment_change_flag__c = true;
            milestonesToUpdate.add(milestone); // Add to update list
        }
    }
*/
    
 
  
  public void afterUpdate(
    List<Milestone__c> newMilestones,
    List<Milestone__c> oldMilestones
  ) {

        if (Test.isRunningTest()) {
        	return;
    	}

    Map<Id, Milestone__c> oldMilestoneMap = new Map<Id, Milestone__c>();
    for (Milestone__c milestone : oldMilestones) {
      oldMilestoneMap.put(milestone.Id, milestone);
    }
    Map<Id, Milestone__c> newMilestoneMap = new Map<Id, Milestone__c>();
    for (Milestone__c milestone : newMilestones) {
      newMilestoneMap.put(milestone.Id, milestone);
    }
    list<Milestone__c> actualDueDateChangedMilestone = new List<Milestone__c>();
    list<Milestone__c> tentativeDueDateChangedMilestone = new List<Milestone__c>();
    List<Milestone__c> commentChangedMilestones = new List<Milestone__c>(); // New list for comment changes  
      
    
    for (Milestone__c milestone : newMilestones) {   
       Milestone__c oldMilestone = oldMilestoneMap.get(milestone.Id);
       
      if (milestone.Actual_Date_of_Completion__c != oldMilestone.get('Actual_Date_of_Completion__c')) {
        actualDueDateChangedMilestone.add(milestone);
      }
      if (milestone.Tentative_Due_Date_of_Completion__c != oldMilestone.get('Tentative_Due_Date_of_Completion__c')) {
        System.debug(
        'TENTATIVE DATE CHANGED - Milestone Id: ' + milestone.Id +
        ', Old Date: ' + oldMilestone.Tentative_Due_Date_of_Completion__c +
        ', New Date: ' + milestone.Tentative_Due_Date_of_Completion__c
      );
        tentativeDueDateChangedMilestone.add(milestone);
      }
      if (milestone.Comments__c != oldMilestone.get('Comments__c')) {
          Milestone__c milestoneToUpdate = new Milestone__c(Id = milestone.Id);
          milestoneToUpdate.Milestone_Comment_change_flag__c = true;
          commentChangedMilestones.add(milestoneToUpdate); // Add to update list
      }    
    }
      
    System.debug('Comment Changed Milestones: ' + commentChangedMilestones);
    // Perform DML update for milestones where comments changed
    if (!commentChangedMilestones.isEmpty()) {
      update commentChangedMilestones; // Perform DML update
      System.debug('Updated Comment Changed Milestones: ' + commentChangedMilestones);
    }
                 
    Map<Milestone__c, list<Payment_Plan_Item__c>> actualDueDateChangedMilestoneMap = new Map<Milestone__c, list<Payment_Plan_Item__c>>();
    if (!actualDueDateChangedMilestone.isEmpty()) {
      actualDueDateChangedMilestoneMap = createMilestonePaymentPlanItemMap(
        actualDueDateChangedMilestone,
        newMilestoneMap
      );
      updateActualDueDateChangedMilestonePaymentPlanItems(
        actualDueDateChangedMilestoneMap
      );
    }
    Map<Milestone__c, list<Payment_Plan_Item__c>> tentativeDueDateChangedMilestoneMap = new Map<Milestone__c, list<Payment_Plan_Item__c>>();
    if (!tentativeDueDateChangedMilestone.isEmpty()) {
      tentativeDueDateChangedMilestoneMap = createMilestonePaymentPlanItemMap(
        tentativeDueDateChangedMilestone,
        newMilestoneMap
      );
      updateTentativeDueDateChangedMilestonePaymentPlanItems(
        tentativeDueDateChangedMilestoneMap
      );
    }

    Map<Milestone__c, list<Offer_Payment_Plan_Item__c>> actualDueDateChangedMilestoneOfferMap = new Map<Milestone__c, list<Offer_Payment_Plan_Item__c>>();
    if (!actualDueDateChangedMilestone.isEmpty()) {
      actualDueDateChangedMilestoneOfferMap = createMilestoneOfferPaymentPlanItemMap(
        actualDueDateChangedMilestone,
        newMilestoneMap
      );
      updateActualDueDateChangedMilestoneOfferPaymentPlanItems(
        actualDueDateChangedMilestoneOfferMap
      );
    }
    
    Map<Milestone__c, list<Offer_Payment_Plan_Item__c>> tentativeDueDateChangedMilestoneOfferMap = new Map<Milestone__c, list<Offer_Payment_Plan_Item__c>>();
    if (!tentativeDueDateChangedMilestone.isEmpty()) {
      tentativeDueDateChangedMilestoneOfferMap = createMilestoneOfferPaymentPlanItemMap(
        tentativeDueDateChangedMilestone,
        newMilestoneMap
      );
      updateTentativeDueDateChangedMilestoneOfferPaymentPlanItems(
        tentativeDueDateChangedMilestoneOfferMap
      );
    }
  }

  private Map<Milestone__c, List<Payment_Plan_Item__c>> createMilestonePaymentPlanItemMap(
    List<Milestone__c> milestones,
    Map<ID, SObject> newMilestoneMap
  ) {
    List<ID> milestoneIds = new List<ID>();
    for (Milestone__c milestone : milestones) {
      milestoneIds.add(milestone.Id);
    }
    List<Payment_Plan_Item__c> paymentPlanItems = [
      SELECT
        Id,
        Milestone__c,
        Proposed_Due_Date__c,
        Actual_Due_Date__c,
        Status__c
      FROM Payment_Plan_Item__c
      WHERE Milestone__c IN :milestoneIds AND Status__c = 'Not Invoiced'
      WITH USER_MODE
    ];
    Map<Milestone__c, List<Payment_Plan_Item__c>> milestonePaymentPlanItemMap = new Map<Milestone__c, List<Payment_Plan_Item__c>>();
    for (Payment_Plan_Item__c paymentPlanItem : paymentPlanItems) {
      Milestone__c milestone = (Milestone__c) newMilestoneMap.get(
        paymentPlanItem.Milestone__c
      );
      if (!milestonePaymentPlanItemMap.containsKey(milestone)) {
        milestonePaymentPlanItemMap.put(
          milestone,
          new List<Payment_Plan_Item__c>()
        );
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
      SELECT
        Id,
        Milestone__c,
        Tentative_Due_Date__c,
        Status__c
      FROM Offer_Payment_Plan_Item__c
      WHERE Milestone__c IN :milestoneIds AND Offer__r.Unit_Sale__c = null
      WITH USER_MODE
    ];

    System.debug(
      'TENTATIVE OFFER PPI - Milestone IDs: ' + milestoneIds
    );

    System.debug(
      'TENTATIVE OFFER PPI - PPI records found: ' +
      OfferPaymentPlanItems.size()
    );

    System.debug(
     'TENTATIVE OFFER PPI - PPI records: ' +
      OfferPaymentPlanItems
    );

    Map<Milestone__c, List<Offer_Payment_Plan_Item__c>> milestoneOfferPaymentPlanItemMap = new Map<Milestone__c, List<Offer_Payment_Plan_Item__c>>();
    for (Offer_Payment_Plan_Item__c offerPaymentPlanItem : OfferPaymentPlanItems) {
      Milestone__c milestone = (Milestone__c) newMilestoneMap.get(
        offerPaymentPlanItem.Milestone__c
      );
      if (!milestoneOfferPaymentPlanItemMap.containsKey(milestone)) {
        milestoneOfferPaymentPlanItemMap.put(
          milestone,
          new List<Offer_Payment_Plan_Item__c>()
        );
      }
      milestoneOfferPaymentPlanItemMap.get(milestone).add(offerPaymentPlanItem);
    }
    return milestoneOfferPaymentPlanItemMap;
  }

  private static void updateActualDueDateChangedMilestonePaymentPlanItems(
    Map<Milestone__c, list<Payment_Plan_Item__c>> actualDueDateChangedMilestoneMap
  ) {
    list<Payment_Plan_Item__c> paymentPlanItems = new List<Payment_Plan_Item__c>();
    List<Milestone__c> milestonesToUpdate = new List<Milestone__c>(); // List to hold milestones to update 
      
    for (Milestone__c milestone : actualDueDateChangedMilestoneMap.keySet()) {
      for (
        Payment_Plan_Item__c paymentPlanItem : actualDueDateChangedMilestoneMap.get(
          milestone
        )) {
        paymentPlanItem.Actual_Due_Date__c = milestone.Actual_Date_of_Completion__c;
        paymentPlanItems.add(paymentPlanItem);
        }
        milestonesToUpdate.add(milestone); // Add milestone to update list 
    }
    update paymentPlanItems;
    // Update the Milestone_Trigger_Flag__c field to false for related milestones
    
    if (!milestonesToUpdate.isEmpty()) {
    // Re-query the milestones to make them writable
    Set<Id> milestoneIds = new Set<Id>();
    for (Milestone__c milestone : milestonesToUpdate) {
        milestoneIds.add(milestone.Id);
    }

    // Re-query the milestones to get modifiable records
    List<Milestone__c> milestonesForUpdate = [
        SELECT Id, Milestone_Trigger_Flag__c 
        FROM Milestone__c 
        WHERE Id IN :milestoneIds
    ];

    // Update the Milestone_Trigger_Flag field
    for (Milestone__c milestone : milestonesForUpdate) {
        milestone.Milestone_Trigger_Flag__c = false;
    }

    // Perform DML update
    update milestonesForUpdate;
}
     
  }

  private static void updateTentativeDueDateChangedMilestonePaymentPlanItems(
    Map<Milestone__c, list<Payment_Plan_Item__c>> tentativeDueDateChangedMilestoneMap
  ) {
    list<Payment_Plan_Item__c> paymentPlanItems = new List<Payment_Plan_Item__c>();
    for (
      Milestone__c milestone : tentativeDueDateChangedMilestoneMap.keySet()
    ) {
      for (
        Payment_Plan_Item__c paymentPlanItem : tentativeDueDateChangedMilestoneMap.get(
          milestone
        )
      ) {
        paymentPlanItem.Actual_Due_Date__c = milestone.Tentative_Due_Date_of_Completion__c;
        paymentPlanItems.add(paymentPlanItem);
      }
    }
    update paymentPlanItems;
  }


  private static void updateActualDueDateChangedMilestoneOfferPaymentPlanItems(
    Map<Milestone__c, list<Offer_Payment_Plan_Item__c>> actualDueDateChangedMilestoneMap
  ) {
    list<Offer_Payment_Plan_Item__c> paymentPlanItems = new List<Offer_Payment_Plan_Item__c>();
    List<Milestone__c> milestonesToUpdate = new List<Milestone__c>(); // List to hold milestones to update 
      
    for (Milestone__c milestone : actualDueDateChangedMilestoneMap.keySet()) {
      for (
        Offer_Payment_Plan_Item__c paymentPlanItem : actualDueDateChangedMilestoneMap.get(
          milestone
        )) {
        paymentPlanItem.Tentative_Due_Date__c = milestone.Actual_Date_of_Completion__c;
        paymentPlanItems.add(paymentPlanItem);
        }
        milestonesToUpdate.add(milestone); // Add milestone to update list 
    }
    update paymentPlanItems;
    // Update the Milestone_Trigger_Flag__c field to false for related milestones
    
    if (!milestonesToUpdate.isEmpty()) {
      // Re-query the milestones to make them writable
      Set<Id> milestoneIds = new Set<Id>();
      for (Milestone__c milestone : milestonesToUpdate) {
          milestoneIds.add(milestone.Id);
      }

      // Re-query the milestones to get modifiable records
      List<Milestone__c> milestonesForUpdate = [
          SELECT Id, Milestone_Trigger_Flag__c 
          FROM Milestone__c 
          WHERE Id IN :milestoneIds
      ];

      // Update the Milestone_Trigger_Flag field
      for (Milestone__c milestone : milestonesForUpdate) {
          milestone.Milestone_Trigger_Flag__c = false;
      }

      // Perform DML update
      update milestonesForUpdate;
    }
     
  }

  private static void updateTentativeDueDateChangedMilestoneOfferPaymentPlanItems(
    Map<Milestone__c, list<Offer_Payment_Plan_Item__c>> tentativeDueDateChangedMilestoneMap
  ) {
    list<Offer_Payment_Plan_Item__c> paymentPlanItems = new List<Offer_Payment_Plan_Item__c>();
    for (
      Milestone__c milestone : tentativeDueDateChangedMilestoneMap.keySet()
    ) {
      for (
        Offer_Payment_Plan_Item__c paymentPlanItem : tentativeDueDateChangedMilestoneMap.get(
          milestone
        )
      ) {
        paymentPlanItem.Tentative_Due_Date__c = milestone.Tentative_Due_Date_of_Completion__c;
        paymentPlanItems.add(paymentPlanItem);
      }
    }
    update paymentPlanItems;
  }
}