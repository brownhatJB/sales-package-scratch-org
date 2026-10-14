/**
 * @module            : Real_Estate_Module
 * @description       :
 * @namespace         :
 * @author            : SREERAM.R
 * @group             :
 * @last modified on  : 07-23-2024
 * @last modified by  : SREERAM.R
 **/
public with sharing class offerConvertToUnitSaleHelper {
  public offerConvertToUnitSaleHelper() {
    system.debug('Inside offerConvertToUnitSaleHelper constructor');
  }

  public static void convertToUnitSaleHelper(
    List<Offer__c> offersConvertToUnitSale
  ) {
    system.debug('Inside offerConvertToUnitSaleHelper.convertToUnitSaleHelper');
    List<Unit_Sale__c> unitSales = new List<Unit_Sale__c>();
    List<Id> offerIds = new List<Id>();
    List<Units__c> units = new List<Units__c>();
    List<Enquiry__c> enquirys = new List<Enquiry__c>();
    if (offersConvertToUnitSale != null && offersConvertToUnitSale.size() > 0) {
      for (Offer__c offer : offersConvertToUnitSale) {
        Unit_Sale__c unitSale = new Unit_Sale__c();
        unitSale.Corporate_customer__c = offer.Account__c;
        unitSale.Customer_Type__c = offer.Customer_Type__c;
        unitSale.Discount__c = offer.Discount_Amount__c;
        unitSale.Enquiry__c = offer.Enquiry__c;
        unitSale.Opportunity__c = offer.Opportunity__c;
        unitSale.Joint_Owner__c = offer.Joint_Owner__c;
        unitSale.Original_Price__c = offer.Unit_Price__c;
        unitSale.Payment_Plan_Template__c = offer.Payment_Plan_Template__c;
        unitSale.Post_Sale_Transaction__c = offer.Post_Sale_Transaction__c;
        unitSale.Primary_Contact__c = offer.Contact__c;
        unitSale.Project__c = Id.valueOf(offer.Project_Id_Formula__c);
        unitSale.Property__c = Id.valueOf(offer.property_id__c);
        unitSale.Sale_Through__c = offer.Sale_through__c;
        unitSale.Broker_Account__c = offer.Broker_Account__c;
        unitSale.Broker_Contact__c = offer.Broker_Contact__c;
        unitSale.Status__c = 'Reserved';
        unitSale.Type__c = offer.Type__c;
        unitSale.Unit_Status__c = 'Available';
        unitSale.Unit__c = offer.Unit__c;
        unitSale.Offer__c = offer.Id;
        unitSale.Tax_Percent__c = offer.Tax_Percentage__c;
        unitSale.Parking_Payment_Plan__c = offer.Parking_Payment_Plan__c;
        unitSale.Total_Parking_Units_Price__c = offer.Total_Parking_Units_Price__c;
        unitSale.Total_Parking_Units_Price_Excluding_Tax__c = offer.Total_Parking_Units_Price_Excluding_Tax__c;
        unitSale.Total_Parking_Units_Tax_Value__c = offer.Total_Parking_Units_Tax_Value__c;
        unitSale.Tax_Code__c = offer.Tax_Code__c;
        unitSale.OwnerId = offer.OwnerId;
        unitSales.add(unitSale);
        offerIds.add(offer.Id);
        Units__c unit = new Units__c();
        unit.Id = offer.Unit__c;
        unit.Status__c = 'Reserved';
        if (offer.Enquiry__c != null) {
          units.add(unit);
        }
        Enquiry__c enquiry = new Enquiry__c();
        enquiry.Id = offer.Enquiry__c;
        enquiry.Stage__c = 'Unit Sale';
        enquiry.Status__c = 'Won';
        if (enquiry.Id != null) {
          enquirys.add(enquiry);
        }
      }
      if (units != null && units.size() > 0) {
        update units;
      }
      if (enquirys != null && enquirys.size() > 0) {
        update enquirys;
      }
    }
    SavePoint sp = Database.setSavepoint();
    insert unitSales;
    List<Joint_Owner__c> jointOwners = [
      SELECT Id, Offer__c
      FROM Joint_Owner__c
      WHERE Offer__c IN :offerIds
    ];
    List<Offer_Item__c> offerItems = [
      SELECT
        Id,
        Amount__c,
        Offer__c,
        Offer__r.Contact__c,
        Offer__r.Enquiry__c,
        Offer__r.Opportunity__c,
        Name__c,
        Offer__r.Unit__r.Project__c,
        Offer__r.Unit__r.Properties__c,
        Tax_Value__c,
        Tax_Code__c,
        Offer__r.Unit__c,
        Offer__r.Account__c,
        Receivable_Item__c,
        Amount_Excluding_Tax__c,
        Offer__r.Unit_Sale__c,
		OwnerId
      FROM Offer_Item__c
      WHERE Offer__c IN :offerIds
    ];
    List<Broker_Accounts__c> brokerAccounts = [
      SELECT Id, Offer__c
      FROM Broker_Accounts__c
      WHERE Offer__c IN :offerIds
    ];
    List<Broker_Contact__c> brokerContacts = [
      SELECT Id, Offer__c
      FROM Broker_Contact__c
      WHERE Offer__c IN :offerIds
    ];
    map<Id, List<Offer_Item__c>> offerIdOfferItemsMap = new Map<Id, List<Offer_Item__c>>();
    if (offerItems != null && offerItems.size() > 0) {
      for (Offer_Item__c OfferItem : offerItems) {
        if (!offerIdOfferItemsMap.containsKey(OfferItem.Offer__c)) {
          offerIdOfferItemsMap.put(
            OfferItem.Offer__c,
            new List<Offer_Item__c>()
          );
        }
        offerIdOfferItemsMap.get(OfferItem.Offer__c).add(OfferItem);
      }
    }
    List<Offer_Payment_Plan_Item__c> offerPaymentPlanItems = [
      SELECT
        Id,
        Milestone__c,
        Tentative_Due_Date__c,
        Offer__c,
        Amount__c,
        Offer__r.Enquiry__c,
        Offer__r.Opportunity__c,
        Offer__r.Unit_Sale__c,
        Offer__r.Contact__c,
        Offer__r.Unit__r.Project__c,
        Offer__r.Unit__r.Properties__c,
        Offer__r.Tax_Code__r.Tax_Percentage__c,
        Offer__r.Unit__c,
        Name__c,
        Tax_Amount__c,
        Offer__r.Account__c,
        Percentage__c,
        Offer_Item__c,
        Amount_Excl_Tax__c,
        Payment_Item_Master__c,
        Display_Order__c,
		OwnerId
      FROM Offer_Payment_Plan_Item__c
      WHERE Offer__c IN :offerIds
    ];
    List<Offer_Payment_Plan_Line_Item__c> offerPaymentPlanLineItems = [
      SELECT
        Id,
        Milestone__c,
        Tentative_Due_Date__c,
        Offer__c,
        Amount__c,
        Offer__r.Enquiry__c,
        Offer__r.Opportunity__c,
        Offer__r.Unit_Sale__c,
        Offer__r.Contact__c,
        Offer__r.Unit__r.Project__c,
        Offer__r.Unit__r.Properties__c,
        Offer__r.Tax_Code__r.Tax_Percentage__c,
        Offer__r.Unit__c,
        Name__c,
        Tax_Amount__c,
        Offer__r.Account__c,
        Percentage__c,
        Offer_Item__c,
        Amount_Excl_Tax__c,
        Payment_Item_Master__c,
        Display_Order__c,
        Parent_Offer_Payment_Plan_Item__c,
		OwnerId
      FROM Offer_Payment_Plan_Line_Item__c
      WHERE Offer__c IN :offerIds
    ];
    map<Id, List<Offer_Payment_Plan_Item__c>> offerIdOfferPaymentPlanItemsMap = new Map<Id, List<Offer_Payment_Plan_Item__c>>();
    if (offerPaymentPlanItems != null && offerPaymentPlanItems.size() > 0) {
      for (
        Offer_Payment_Plan_Item__c offerPaymentPlanItem : offerPaymentPlanItems
      ) {
        if (
          !offerIdOfferPaymentPlanItemsMap.containsKey(
            offerPaymentPlanItem.Offer__c
          )
        ) {
          offerIdOfferPaymentPlanItemsMap.put(
            offerPaymentPlanItem.Offer__c,
            new List<Offer_Payment_Plan_Item__c>()
          );
        }
        offerIdOfferPaymentPlanItemsMap.get(offerPaymentPlanItem.Offer__c)
          .add(offerPaymentPlanItem);
      }
    }
    List<Offer__c> offersForUpdate = new List<Offer__c>();
    List<Receivable_Item__c> receivableItems = new List<Receivable_Item__c>();
    Set<Id> paymentItemMasterIds = new Set<Id>();
    map<Id, Id> offerIdUnitSaleIdmap = new Map<Id, Id>();
    if (unitSales != null && unitSales.size() > 0) {
      for (Unit_Sale__c UnitSale : unitSales) {
        if (!offerIdUnitSaleIdmap.containsKey(UnitSale.Offer__c)) {
          offerIdUnitSaleIdmap.put(UnitSale.Offer__c, UnitSale.Id);
        }
        Offer__c offerForUpdate = new Offer__c();
        offerForUpdate.Id = UnitSale.Offer__c;
        offerForUpdate.Stages__c = 'Unit Sale';
        offerForUpdate.Status__c = 'Converted To Sale';
        offerForUpdate.Unit_Sale__c = UnitSale.Id;
        offersForUpdate.add(offerForUpdate);
        List<Offer_Item__c> offerItemsList = new List<Offer_Item__c>();
        offerItemsList = offerIdOfferItemsMap.get(UnitSale.Offer__c);
        if (offerItemsList != null && offerItemsList.size() > 0) {
          for (Offer_Item__c offerItem : offerItemsList) {
            Receivable_Item__c receivableItem = new Receivable_Item__c();
            receivableItem.Unit_Sale__c = UnitSale.Id;
            receivableItem.Amount__c = offerItem.Amount__c;
            receivableItem.Contact__c = offerItem.Offer__r.Contact__c;
            receivableItem.Enquiry__c = offerItem.Offer__r.Enquiry__c;
            receivableItem.Opportunity__c = offerItem.Offer__r.Opportunity__c;
            receivableItem.Name__c = offerItem.Name__c;
            receivableItem.Project__c = offerItem.Offer__r.Unit__r.Project__c;
            receivableItem.Properties__c = offerItem.Offer__r.Unit__r.Properties__c;
            receivableItem.Status__c = 'Active';
            receivableItem.Tax_Amount__c = offerItem.Tax_Value__c;
            receivableItem.Tax_Code__c = offerItem.Tax_Code__c;
            receivableItem.Units__c = offerItem.Offer__r.Unit__c;
            receivableItem.Account__c = offerItem.Offer__r.Account__c;
            receivableItem.Name__c = offerItem.Name__c;
            receivableItem.Offer_Item__c = offerItem.Id;
            receivableItem.Item__c = offerItem.Receivable_Item__c;
            receivableItem.Amount_Excluding_tax__c = offerItem.Amount_Excluding_Tax__c;
            receivableItem.OwnerId = offerItem.OwnerId;
            paymentItemMasterIds.add(offerItem.Receivable_Item__c);
            receivableItems.add(receivableItem);
          }
        }
      }
      update offersForUpdate;
    }
    insert receivableItems;
    List<Payment_Item_Master__c> paymentItemMasters = [
      SELECT Id, Main_item__c
      FROM Payment_Item_Master__c
      WHERE Id IN :paymentItemMasterIds
    ];
    map<Id, Payment_Item_Master__c> paymentItemMasterMap = new Map<Id, Payment_Item_Master__c>();
    for (Payment_Item_Master__c paymentItemMaster : paymentItemMasters) {
      if (!paymentItemMasterMap.containsKey(paymentItemMaster.Id)) {
        paymentItemMasterMap.put(paymentItemMaster.Id, paymentItemMaster);
      }
    }
    map<Id, Id> offerItemIdReceivableItemIdMap = new Map<Id, Id>();
    map<Id, List<Receivable_Item__c>> unitSaleIdReceivableItemsMap = new Map<Id, List<Receivable_Item__c>>();
    if (receivableItems != null && receivableItems.size() > 0) {
      for (Receivable_Item__c ReceivableItem : receivableItems) {
        if (
          !offerItemIdReceivableItemIdMap.containsKey(
            ReceivableItem.Offer_Item__c
          )
        ) {
          offerItemIdReceivableItemIdMap.put(
            ReceivableItem.Offer_Item__c,
            ReceivableItem.Id
          );
        }
      }
    }
    if (receivableItems != null && receivableItems.size() > 0) {
      for (Receivable_Item__c receivableItem : receivableItems) {
        if (
          !unitSaleIdReceivableItemsMap.containsKey(receivableItem.Unit_Sale__c)
        ) {
          unitSaleIdReceivableItemsMap.put(
            receivableItem.Unit_Sale__c,
            new List<Receivable_Item__c>()
          );
        }
        unitSaleIdReceivableItemsMap.get(receivableItem.Unit_Sale__c)
          .add(receivableItem);
      }
    }
    List<Payment_Plan_Item__c> paymentPlanItems = new List<Payment_Plan_Item__c>();
    List<Payment_Plan_Line_Item__c> paymentPlanLineItems = new List<Payment_Plan_Line_Item__c>();
    List<Unit_Sale__c> newUnitSales = new List<Unit_Sale__c>();
    if (unitSales != null && unitSales.size() > 0) {
      for (Unit_Sale__c UnitSale : unitSales) {
        List<Offer_Payment_Plan_Item__c> OfferPaymentPlanItemsList = new List<Offer_Payment_Plan_Item__c>();
        OfferPaymentPlanItemsList = offerIdOfferPaymentPlanItemsMap.get(
          UnitSale.Offer__c
        );
        if (
          OfferPaymentPlanItemsList != null &&
          OfferPaymentPlanItemsList.size() > 0
        ) {
          for (
            Offer_Payment_Plan_Item__c OfferPaymentPlanItem : OfferPaymentPlanItemsList
          ) {
            Payment_Plan_Item__c PaymentPlanItem = new Payment_Plan_Item__c();
            PaymentPlanItem.Milestone__c = OfferPaymentPlanItem.Milestone__c;
            PaymentPlanItem.Actual_Due_Date__c = OfferPaymentPlanItem.Tentative_Due_Date__c;
            PaymentPlanItem.Amount__c = OfferPaymentPlanItem.Amount__c;
            PaymentPlanItem.Enquiry__c = OfferPaymentPlanItem.Offer__r.Enquiry__c;
            PaymentPlanItem.Opportunity__c = OfferPaymentPlanItem.Offer__r.Opportunity__c;
            PaymentPlanItem.Offer__c = OfferPaymentPlanItem.Offer__c;
            PaymentPlanItem.Unit_Sale__c = UnitSale.Id;
            PaymentPlanItem.Contact__c = OfferPaymentPlanItem.Offer__r.Contact__c;
            PaymentPlanItem.Project__c = OfferPaymentPlanItem.Offer__r.Unit__r.Project__c;
            PaymentPlanItem.Properties__c = OfferPaymentPlanItem.Offer__r.Unit__r.Properties__c;
            PaymentPlanItem.Tax_Percentage__c = OfferPaymentPlanItem.Offer__r.Tax_Code__r.Tax_Percentage__c;
            PaymentPlanItem.Units__c = OfferPaymentPlanItem.Offer__r.Unit__c;
            PaymentPlanItem.Payment_Plan_Item_Name__c = OfferPaymentPlanItem.Name__c;
            PaymentPlanItem.Tax_Amount__c = OfferPaymentPlanItem.Tax_Amount__c;
            PaymentPlanItem.Total_Amount_Excluding_Tax__c = OfferPaymentPlanItem.Amount_Excl_Tax__c;
            PaymentPlanItem.Customer_Account__c = OfferPaymentPlanItem.Offer__r.Account__c;
            PaymentPlanItem.Contact__c = OfferPaymentPlanItem.Offer__r.Contact__c;
            PaymentPlanItem.Display_Order__c = OfferPaymentPlanItem.Display_Order__c;
            PaymentPlanItem.Installment_Percentage__c = OfferPaymentPlanItem.Percentage__c;
            PaymentPlanItem.Offer_Item__c = OfferPaymentPlanItem.Offer_Item__c;
            PaymentPlanItem.Receivable_Item__c = offerItemIdReceivableItemIdMap.get(
              OfferPaymentPlanItem.Offer_Item__c
            );
            PaymentPlanItem.Name__c = OfferPaymentPlanItem.Payment_Item_Master__c;
            PaymentPlanItem.Offer_Payment_Plan_Item__c = OfferPaymentPlanItem.Id;
            PaymentPlanItem.OwnerId = OfferPaymentPlanItem.OwnerId;
            paymentPlanItems.add(PaymentPlanItem);
          }
        }

        if (
          offerPaymentPlanLineItems != null &&
          offerPaymentPlanLineItems.size() > 0
        ) {
          for (
            Offer_Payment_Plan_Line_Item__c OfferPaymentPlanLineItem : offerPaymentPlanLineItems
          ) {
            Payment_Plan_Line_Item__c PaymentPlanLineItem = new Payment_Plan_Line_Item__c();
            PaymentPlanLineItem.Milestone__c = OfferPaymentPlanLineItem.Milestone__c;
            PaymentPlanLineItem.Actual_Due_Date__c = OfferPaymentPlanLineItem.Tentative_Due_Date__c;
            PaymentPlanLineItem.Amount__c = OfferPaymentPlanLineItem.Amount__c;
            PaymentPlanLineItem.Opportunity__c = OfferPaymentPlanLineItem.Offer__r.Opportunity__c;
            PaymentPlanLineItem.Offer__c = OfferPaymentPlanLineItem.Offer__c;
            PaymentPlanLineItem.Unit_Sale__c = UnitSale.Id;
            PaymentPlanLineItem.Contact__c = OfferPaymentPlanLineItem.Offer__r.Contact__c;
            PaymentPlanLineItem.Project__c = OfferPaymentPlanLineItem.Offer__r.Unit__r.Project__c;
            PaymentPlanLineItem.Properties__c = OfferPaymentPlanLineItem.Offer__r.Unit__r.Properties__c;
            PaymentPlanLineItem.Tax_Percentage__c = OfferPaymentPlanLineItem.Offer__r.Tax_Code__r.Tax_Percentage__c;
            PaymentPlanLineItem.Units__c = OfferPaymentPlanLineItem.Offer__r.Unit__c;
            PaymentPlanLineItem.Payment_Plan_Item_Name__c = OfferPaymentPlanLineItem.Name__c;
            PaymentPlanLineItem.Tax_Amount__c = OfferPaymentPlanLineItem.Tax_Amount__c;
            PaymentPlanLineItem.Total_Amount_Excluding_Tax__c = OfferPaymentPlanLineItem.Amount_Excl_Tax__c;
            PaymentPlanLineItem.Customer_Account__c = OfferPaymentPlanLineItem.Offer__r.Account__c;
            PaymentPlanLineItem.Contact__c = OfferPaymentPlanLineItem.Offer__r.Contact__c;
            PaymentPlanLineItem.Display_Order__c = OfferPaymentPlanLineItem.Display_Order__c;
            PaymentPlanLineItem.Installment_Percentage__c = OfferPaymentPlanLineItem.Percentage__c;
            PaymentPlanLineItem.Offer_Item__c = OfferPaymentPlanLineItem.Offer_Item__c;
            PaymentPlanLineItem.Name__c = OfferPaymentPlanLineItem.Payment_Item_Master__c;
            PaymentPlanLineItem.Offer_Payment_Plan_Item__c = OfferPaymentPlanLineItem.Parent_Offer_Payment_Plan_Item__c;
            paymentPlanLineItems.add(PaymentPlanLineItem);
          }
        }
          
          
         
      }
      insert paymentPlanItems;
        
Map<Id, List<Payment_Plan_Item__c>> paymentPlanItemMap = new Map<Id, List<Payment_Plan_Item__c>>();
for (Payment_Plan_Item__c paymentPlanItem : paymentPlanItems) {
    if (paymentPlanItemMap.containsKey(paymentPlanItem.Offer_Payment_Plan_Item__c)) {
        paymentPlanItemMap.get(paymentPlanItem.Offer_Payment_Plan_Item__c).add(paymentPlanItem);
    } else {
        paymentPlanItemMap.put(paymentPlanItem.Offer_Payment_Plan_Item__c, new List<Payment_Plan_Item__c>{paymentPlanItem});
    }
}
for (Payment_Plan_Line_Item__c paymentPlanLineItem : paymentPlanLineItems) {
    if (paymentPlanItemMap.containsKey(paymentPlanLineItem.Offer_Payment_Plan_Item__c)) {
        List<Payment_Plan_Item__c> parentItems = paymentPlanItemMap.get(paymentPlanLineItem.Offer_Payment_Plan_Item__c);
        if (!parentItems.isEmpty()) {
            paymentPlanLineItem.Parent_Payment_Plan_Item__c = parentItems[0].Id;
        }
    }
}

        insert paymentPlanLineItems;
        
    }
      
      
      
    if (unitSales != null && unitSales.size() > 0) {
      for (Unit_Sale__c UnitSale : unitSales) {
        List<Receivable_Item__c> newReceivableItems = new List<Receivable_Item__c>();
        newReceivableItems = unitSaleIdReceivableItemsMap.get(UnitSale.Id);
        Decimal totalDealValue = 0;
        Decimal additionalCharges = 0;
        Decimal additionalChargesTax = 0;
        Decimal additionalChargesExTax = 0;
        Unit_Sale__c newUnitSale = new Unit_Sale__c();
        if (newReceivableItems != null && newReceivableItems.size() > 0) {
          for (Receivable_Item__c receivableItem : newReceivableItems) {
            totalDealValue += receivableItem.Amount__c;
            if (
              paymentItemMasterMap.get(receivableItem.Item__c).Main_item__c !=
              true
            ) {
              additionalCharges += receivableItem.Amount__c;
              additionalChargesTax += receivableItem.Tax_Amount__c;
              additionalChargesExTax += (receivableItem.Amount__c -
              receivableItem.Tax_Amount__c);
            }
          }
        }
        newUnitSale.Id = UnitSale.Id;
        newUnitSale.Additional_charges__c = additionalCharges;
        newUnitSale.Additional_charges_extax__c = additionalChargesExTax;
        newUnitSale.Additional_Charges_Tax__c = additionalChargesTax;
        newUnitSale.Total_deal_value__c = totalDealValue;
        newUnitSale.Payment_Plan_Items_Created__c = true;
        newUnitSales.add(newUnitSale);
      }
    }
    update newUnitSales;
    List<Joint_Owner__c> jointOwnersUpdate = new List<Joint_Owner__c>();
    List<Unit_Sale__c> unitSalesUpdate = new List<Unit_Sale__c>();
    Set<Id> unitSalesIdsUpdate = new Set<Id>();
    if (jointOwners != null && jointOwners.size() > 0) {
      for (Joint_Owner__c jointOwner : jointOwners) {
        Joint_Owner__c jointOwnerUpdate = new Joint_Owner__c();
        jointOwnerUpdate.Id = jointOwner.Id;
        jointOwnerUpdate.Unit_Sale__c = offerIdUnitSaleIdmap.get(
          jointOwner.Offer__c
        );
        jointOwnersUpdate.add(jointOwnerUpdate);
        unitSalesIdsUpdate.add(offerIdUnitSaleIdmap.get(jointOwner.Offer__c));
      }
      for (Id unitSaleId : unitSalesIdsUpdate) {
        Unit_Sale__c unitSale = new Unit_Sale__c();
        unitSale.Id = unitSaleId;
        unitSale.Joint_ownership__c = 'Yes';
        unitSalesUpdate.add(unitSale);
      }
    }
    update jointOwnersUpdate;
    update unitSalesUpdate;
    List<Broker_Accounts__c> updateBrokerAccounts = new List<Broker_Accounts__c>();
    List<Broker_Contact__c> updateBrokerContacts = new List<Broker_Contact__c>();
    Set<Unit_Sale__c> unitSalesSaleThroughUpdate = new Set<Unit_Sale__c>();
    if (brokerAccounts != null && brokerAccounts.size() > 0) {
      for (Broker_Accounts__c brokerAccount : brokerAccounts) {
        Broker_Accounts__c brokerAccountUpdate = new Broker_Accounts__c();
        brokerAccountUpdate.Id = brokerAccount.Id;
        brokerAccountUpdate.Unit_Sale__c = offerIdUnitSaleIdmap.get(
          brokerAccount.Offer__c
        );
        updateBrokerAccounts.add(brokerAccountUpdate);
        Unit_Sale__c unitSale = new Unit_Sale__c();
        unitSale.Id = offerIdUnitSaleIdmap.get(brokerAccount.Offer__c);
        unitSale.Sale_Through__c = 'Agent';
        unitSalesSaleThroughUpdate.add(unitSale);
      }
    }
    if (brokerContacts != null && brokerContacts.size() > 0) {
      for (Broker_Contact__c brokerContact : brokerContacts) {
        Broker_Contact__c brokerContactUpdate = new Broker_Contact__c();
        brokerContactUpdate.Id = brokerContact.Id;
        brokerContactUpdate.Unit_Sale__c = offerIdUnitSaleIdmap.get(
          brokerContact.Offer__c
        );
        updateBrokerContacts.add(brokerContactUpdate);
        Unit_Sale__c unitSale = new Unit_Sale__c();
        unitSale.Id = offerIdUnitSaleIdmap.get(brokerContact.Offer__c);
        unitSale.Sale_Through__c = 'Agent';
        unitSalesSaleThroughUpdate.add(unitSale);
      }
    }
    List<Unit_Sale__c> unitSalesForUpdate = new List<Unit_Sale__c>();
    unitSalesForUpdate.addAll(unitSalesSaleThroughUpdate);
    update updateBrokerAccounts;
    update updateBrokerContacts;
    update unitSalesForUpdate;
  }
}