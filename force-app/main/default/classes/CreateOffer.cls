/**
 * @module            : Real_Estate_Module
 * @description       : Create Offer
 * @namespace         :
 * @author            : SREERAM.R
 * @group             : Unit Search
 * @last modified on  : 07-28-2026
 * @last modified by  : SREERAM.R
 **/
public with sharing class CreateOffer {
  /**
   * @description get filter class
   * @return CreateOfferSalesProposalData returns filter class
   */
  @AuraEnabled(cacheable=true)
  public static CreateOfferSalesProposalData getFormData() {
    return new CreateOfferSalesProposalData();
  }

  /**
   * @description Method used to create offer
   * @param createOfferSalesProposalData createOfferSalesProposalData is the wrapper class to create sales proposal an offer
   * @return newOfferIds offer ids
   */
	@AuraEnabled
	public static List<String> createOfferWithSelectedUnits(
    	CreateOfferSalesProposalData createOfferSalesProposalData
	) {
    	List<String> newOfferIds = new List<String>();
    	try {

        	// License_Expiry_Control__mdt licenseConfig = [
          //   	SELECT License_Expiry_Date__c
          //   	FROM License_Expiry_Control__mdt
          //   	WHERE DeveloperName = 'License_Expiry_Date_Value'
          //   	LIMIT 1
        	// ];

        	// if (licenseConfig == null || licenseConfig.License_Expiry_Date__c == null) {
          //   	throw new AuraHandledException('License configuration is missing or invalid.');
        	// }
        	// if (licenseConfig.License_Expiry_Date__c < Date.today()) {
          //   	throw new AuraHandledException('License has expired. Please contact admin.');
        	// }

// Lock all selected units
List<Units__c> units = [
    SELECT Id, Name, Status__c
    FROM Units__c
    WHERE Id IN :createOfferSalesProposalData.selectedIds
    FOR UPDATE
];

// Revalidate after acquiring the lock
for (Units__c unit : units) {
    if (unit.Status__c != 'Available') {
        throw new AuraHandledException(
            'Unit "' + unit.Name + '" is no longer available.'
        );
    }
}

// Continue with offer creation
List<Offer__c> offers = newOffer(createOfferSalesProposalData);

if (offers != null && offers.size() > 0) {
    insert offers;
}

        	List<Units__c> parkingUnits = new List<Units__c>();
        	if (offers != null && offers.size() > 0) {
            	if (
                	updateParkingUnits(offers, createOfferSalesProposalData).parkingUnits != null &&
                	updateParkingUnits(offers, createOfferSalesProposalData).parkingUnits.size() > 0
            	) {
                	parkingUnits = updateParkingUnits(
                    	offers,
                    	createOfferSalesProposalData
                	).parkingUnits;
            	}
            	newOfferIds = updateParkingUnits(offers, createOfferSalesProposalData)
            	    .newOfferIds;
        	}

        	List<Offer__c> offerForUpdate = new List<Offer__c>();
        	if (parkingUnits != null & parkingUnits.size() > 0) {
            	update parkingUnits;
        	}
        	offerForUpdate = updateOffer(offers);
        	if (offerForUpdate != null & offerForUpdate.size() > 0) {
            	update offerForUpdate;
        	}
    	} catch (Exception e) {
        	throw e;
    	}
    	return newOfferIds;
	}


  /**
   * @description
   * @param createOfferSalesProposalData createOfferSalesProposalData is the wrapper class to create sales proposal an offer
   * @return newOffers
   */
  private static List<Offer__c> newOffer(
    CreateOfferSalesProposalData createOfferSalesProposalData
  ) {
    Country__c country = [
      SELECT id
      FROM Country__c
      WITH USER_MODE
      LIMIT 1
    ];
    List<Offer__c> newOffers = new List<Offer__c>();

    if (createOfferSalesProposalData.enqRecordId != null) {
      Enquiry__c enquiry = [
        SELECT
          Id,
          Account__c,
          Stage__c,
          Contact__c,
          Contact__r.Email,
          Customer_Type__c
        FROM Enquiry__c
        WHERE Id = :createOfferSalesProposalData.enqRecordId
        WITH SECURITY_ENFORCED
      ];

      for (Units__c unit : [
        SELECT Id, Name, Unit_Price__c, Tax_Code__c, Default_Payment_Plan__c,Project__r.Id,Properties__r.Id,Payment_Plan_Filter__c
        FROM Units__c
        WHERE Id IN :createOfferSalesProposalData.selectedIds
        WITH SECURITY_ENFORCED
      ]) {
        Offer__c newOffer = new Offer__c();
        newOffer.Unit__c = unit.Id;
        newOffer.Enquiry__c = enquiry.Id;
        newOffer.Account__c = enquiry.Account__c;
        newOffer.Contact__c = enquiry.Contact__c;
        newOffer.Tax_Code__c = unit.Tax_Code__c;
        newOffer.Country__c = country.Id;
        newOffer.Payment_Plan_Template__c = unit.Default_Payment_Plan__c;
        newOffer.Customer_Type__c = enquiry.Customer_Type__c;
        newOffer.Valid_from__c = Date.today();
        newOffer.Payment_Plan_Filter__c = unit.Payment_Plan_Filter__c;
        if (newOffer.Valid_from__c != null) {
          newOffer.Valid_to__c = newOffer.Valid_from__c.addDays(7);
        }
        newOffers.add(newOffer);
      }
      enquiry.Stage__c = 'Offer';
      update enquiry;
    }

    if (createOfferSalesProposalData.opportunity != null) {
      Opportunity opp = [
        SELECT Id, AccountId , Customer_Type__c
        FROM Opportunity
        WHERE Id = :createOfferSalesProposalData.opportunity
        WITH SECURITY_ENFORCED
      ];

      for (Units__c unit : [
        SELECT Id, Name, Unit_Price__c, Tax_Code__c, Default_Payment_Plan__c,Project__r.Id,Properties__r.Id
        FROM Units__c
        WHERE Id IN :createOfferSalesProposalData.selectedIds
        WITH SECURITY_ENFORCED
      ]) {
        Offer__c newOffer = new Offer__c();
        newOffer.Unit__c = unit.Id;
        newOffer.Opportunity__c = createOfferSalesProposalData.opportunity;
        newOffer.Account__c = opp.AccountId;
        newOffer.Tax_Code__c = unit.Tax_Code__c;
        newOffer.Country__c = country.Id;
        newOffer.Payment_Plan_Template__c = unit.Default_Payment_Plan__c;
        newOffer.Customer_Type__c = opp.Customer_Type__c;
        newOffer.Valid_from__c = Date.today();
        if (newOffer.Valid_from__c != null) {
          newOffer.Valid_to__c = newOffer.Valid_from__c.addDays(7);
        }
        if(unit.Project__r.Id != null){
		  	newOffer.Project__c = unit.Project__r.Id;           
         }
        if(unit.Project__r.Id != null){
        	newOffer.Properties__c = unit.Properties__r.Id;              
         } 
        newOffers.add(newOffer);
      }
    }

    return newOffers;
  }

  /**
   * @description
   * @param offers
   * @param createOfferSalesProposalData
   * @return UpdateParkingUnitsResult
   */
  private static UpdateParkingUnitsResult updateParkingUnits(
    List<Offer__c> offers,
    CreateOfferSalesProposalData createOfferSalesProposalData
  ) {
    List<Units__c> parkingUnits = new List<Units__c>();
    List<String> newOfferIds = new List<String>();

    for (Offer__c offerCreated : offers) {
      String offerId = offerCreated.Id;
      String unitId = offerCreated.Unit__c;
      newOfferIds.add(offerId);

      List<String> parkingUnitsIds = new List<String>();
      if (
        createOfferSalesProposalData.selectedUnitsParkingUnitsMap != null &&
        createOfferSalesProposalData.selectedUnitsParkingUnitsMap.size() > 0
      ) {
        parkingUnitsIds = createOfferSalesProposalData.selectedUnitsParkingUnitsMap.get(
          unitId
        );
      }

      if (parkingUnitsIds != null && parkingUnitsIds.size() > 0) {
        for (String id : parkingUnitsIds) {
          Units__c parkingUnit = new Units__c();
          parkingUnit.Id = id;
          parkingUnit.Parent_Unit__c = offerCreated.Unit__c;
          parkingUnit.Status__c = 'Under Offer';
          parkingUnits.add(parkingUnit);
        }
      }
    }

    return new UpdateParkingUnitsResult(parkingUnits, newOfferIds);
  }

  /**
   * @description
   * @param offers
   * @return offerForUpdate
   */
  private static List<Offer__c> updateOffer(List<Offer__c> offers) {
    Set<Id> parentUnits = new Set<Id>();
    for (Offer__c offer : offers) {
      parentUnits.add(offer.Unit__c);
    }
    List<Units__c> relatedParkingUnitsList = [
      SELECT Id, Unit_Price__c, Parent_Unit__c
      FROM Units__c
      WHERE Parent_Unit__c IN :parentUnits
      WITH USER_MODE
    ];
    Map<Id, List<Units__c>> parentUnitParkingUnitsMap = new Map<Id, List<Units__c>>();
    if (relatedParkingUnitsList != null & relatedParkingUnitsList.size() > 0) {
      for (Units__c unit : relatedParkingUnitsList) {
        if (!parentUnitParkingUnitsMap.containsKey(unit.Parent_Unit__c)) {
          parentUnitParkingUnitsMap.put(
            unit.Parent_Unit__c,
            new List<Units__c>()
          );
        }
        parentUnitParkingUnitsMap.get(unit.Parent_Unit__c).add(unit);
      }
    }
    List<Offer__c> offerForUpdate = new List<Offer__c>();
    for (Offer__c offer : offers) {
      Decimal parkingUnitAmount = 0;
      List<Units__c> relatedParkingUnits = new List<Units__c>();
      if (
        parentUnitParkingUnitsMap.get(offer.Unit__c) != null &&
        parentUnitParkingUnitsMap.get(offer.Unit__c).size() > 0
      ) {
        relatedParkingUnits = parentUnitParkingUnitsMap.get(offer.Unit__c);
      }
      if (relatedParkingUnits != null && relatedParkingUnits.size() > 0) {
        for (Units__c parkUnt : relatedParkingUnits) {
          parkingUnitAmount += parkUnt.Unit_Price__c;
        }
      }
      Offer__c newOffer = new Offer__c();
      newOffer.Id = offer.Id;
      newOffer.Total_Parking_Units_Price_Excluding_Tax__c = parkingUnitAmount;
      offerForUpdate.add(newOffer);
    }
    return offerForUpdate;
  }

  @AuraEnabled(Cacheable=true)
  public static List<Offer__c> checkReservationConflict(List<Id> unitIds) {

if (unitIds == null || unitIds.isEmpty()) {
    throw new AuraHandledException('At least one Unit Id is required.');
}

    try {
      Set<String> excludedStatuses = new Set<String>();

      for(Conflict_Reservation_Status__mdt config :
          [
              SELECT Status_Value__c
              FROM Conflict_Reservation_Status__mdt
              WHERE Exclude_From_Conflict__c = true
          ]
      ) {

          if(String.isNotBlank(config.Status_Value__c)) {
              excludedStatuses.add(config.Status_Value__c);
          }
      }

String soql =
    'SELECT Id, Name, Owner.Name, Status__c, CreatedDate, OwnerId, Owner.Email,' +
    ' Unit__c, Unit__r.Name ' +
    'FROM Offer__c ' +
    'WHERE Unit__c IN :unitIds ' +
    'AND Status__c NOT IN :excludedStatuses ' +
    'ORDER BY Unit__r.Name, CreatedDate DESC';

      List<Offer__c> conflictingOffers = Database.query(soql);

      return conflictingOffers;
    } catch(Exception e) {
      throw new AuraHandledException('Error while fetching coflicting offers: ' + e.getMessage());
    }
  }


@AuraEnabled
public static List<String> validateUnitAvailability(List<Id> unitIds) {
    List<String> unavailableUnits = new List<String>();

    for (Units__c unit : [
        SELECT Id, Name, Status__c
        FROM Units__c
        WHERE Id IN :unitIds
    ]) {
        if (unit.Status__c != 'Available') {
            unavailableUnits.add(unit.Name);
        }
    }

    return unavailableUnits;
}

  @AuraEnabled
public static void sendConflictAlert(
    Id unitId,
    Id oppId,
    Id enquiryId
) {

    try {

        if (unitId == null) {
            return;
        }

        Id parentId = oppId != null ? oppId : enquiryId;

        if (parentId == null) {
            throw new AuraHandledException(
                'Either Opportunity Id or Enquiry Id is required.'
            );
        }

        Opportunity opp = null;
        Enquiry__c enquiry = null;

        if (oppId != null) {

            List<Opportunity> oppList = [
                SELECT Id, Name, Owner.Name
                FROM Opportunity
                WHERE Id = :oppId
                LIMIT 1
            ];

            if (!oppList.isEmpty()) {
                opp = oppList[0];
            }

        } else if (enquiryId != null) {

            List<Enquiry__c> enquiryList = [
                SELECT Id, Name
                FROM Enquiry__c
                WHERE Id = :enquiryId
                LIMIT 1
            ];

            if (!enquiryList.isEmpty()) {
                enquiry = enquiryList[0];
            }
        }

        // Unit
        Units__c unitRec = [
            SELECT Id, Name
            FROM Units__c
            WHERE Id = :unitId
            LIMIT 1
        ];

        Set<String> excludedStatuses = new Set<String>();

        for (
            Conflict_Reservation_Status__mdt config :
            [
                SELECT Status_Value__c
                FROM Conflict_Reservation_Status__mdt
                WHERE Exclude_From_Conflict__c = true
            ]
        ) {

            if (String.isNotBlank(config.Status_Value__c)) {
                excludedStatuses.add(config.Status_Value__c);
            }
        }

        // Conflicting Offers
        List<Offer__c> conflicts = [
            SELECT
                Id,
                Name,
                Owner.Name,
                Status__c,
                CreatedDate
            FROM Offer__c
            WHERE Unit__c = :unitId
            AND Status__c NOT IN :excludedStatuses
            ORDER BY CreatedDate DESC
        ];

        if (conflicts.isEmpty()) {
            return;
        }

        // Prevent duplicate emails on same day
        List<Task> recentAlert = [
            SELECT Id
            FROM Task
            WHERE WhatId = :parentId
            AND Subject = 'Conflict Notification Sent'
            AND ActivityDate = TODAY
            LIMIT 1
        ];

        if (!recentAlert.isEmpty()) {
            return;
        }

        // Public Group
        List<Group> groups = [
            SELECT Id
            FROM Group
            WHERE Type = 'Regular'
            AND DeveloperName = 'Reservation_Conflict_Alerts'
            LIMIT 1
        ];

        if (groups.isEmpty()) {
            return;
        }

        List<GroupMember> groupMembers = [
            SELECT UserOrGroupId
            FROM GroupMember
            WHERE GroupId = :groups[0].Id
        ];

        Set<Id> userIds = new Set<Id>();

        for (GroupMember gm : groupMembers) {

            String memberId = String.valueOf(gm.UserOrGroupId);

            if (memberId.startsWith('005')) {
                userIds.add(gm.UserOrGroupId);
            }
        }

        if (userIds.isEmpty()) {
            return;
        }

        List<User> users = [
            SELECT Id, Email
            FROM User
            WHERE Id IN :userIds
            AND IsActive = true
            AND Email != null
        ];

        List<String> emails = new List<String>();

        for (User u : users) {
            emails.add(u.Email);
        }

        if (emails.isEmpty()) {
            return;
        }

        String rows = '';

        for (Offer__c o : conflicts) {

            rows +=
                '<tr>' +
                    '<td style="padding:8px;border:1px solid #ddd;">'
                    + o.Name +
                    '</td>' +

                    '<td style="padding:8px;border:1px solid #ddd;">'
                    + (o.Owner != null ? o.Owner.Name : '')
                    + '</td>' +

                    '<td style="padding:8px;border:1px solid #ddd;">'
                    + o.Status__c +
                    '</td>' +

                    '<td style="padding:8px;border:1px solid #ddd;">'
                    + o.CreatedDate.format('dd/MM/yyyy hh:mm a')
                    + '</td>' +

                '</tr>';
        }

        String emailBody =
            '<html><body style="font-family:Arial;">'

            + '<h2 style="color:#c62828;">'
            + 'Reservation Conflict Detected'
            + '</h2>'

            + '<p>'
            + 'A reservation conflict was detected while attempting reservation creation.'
            + '</p>'

            + '<table style="margin-bottom:20px;">'

                + '<tr>'
                    + '<td><b>Unit</b></td>'
                    + '<td style="padding-left:12px;">'
                    + unitRec.Name
                    + '</td>'
                + '</tr>'

                + (opp != null ?

                    '<tr>'
                        + '<td><b>Opportunity</b></td>'
                        + '<td style="padding-left:12px;">'
                        + opp.Name
                        + '</td>'
                    + '</tr>'

                    : '')

                + (enquiry != null ?

                    '<tr>'
                        + '<td><b>Enquiry</b></td>'
                        + '<td style="padding-left:12px;">'
                        + enquiry.Name
                        + '</td>'
                    + '</tr>'

                    : '')

            + '</table>'

            + '<table style="border-collapse:collapse;width:100%;">'

                + '<thead>'

                    + '<tr>'

                        + '<th style="padding:8px;border:1px solid #ddd;background:#f2f2f2;">'
                        + 'Offer'
                        + '</th>'

                        + '<th style="padding:8px;border:1px solid #ddd;background:#f2f2f2;">'
                        + 'Owner'
                        + '</th>'

                        + '<th style="padding:8px;border:1px solid #ddd;background:#f2f2f2;">'
                        + 'Status'
                        + '</th>'

                        + '<th style="padding:8px;border:1px solid #ddd;background:#f2f2f2;">'
                        + 'Created Date'
                        + '</th>'

                    + '</tr>'

                + '</thead>'

                + '<tbody>'
                + rows
                + '</tbody>'

            + '</table>'

            + '<br/>'

            + '<p>'
            + 'Please review the reservation conflict.'
            + '</p>'

            + '</body></html>';

        Messaging.SingleEmailMessage mail =
            new Messaging.SingleEmailMessage();

        mail.setToAddresses(emails);

        mail.setSubject(
            '⚠ Reservation Conflict - Unit ' + unitRec.Name
        );

        mail.setHtmlBody(emailBody);

        mail.setSaveAsActivity(false);

        Messaging.sendEmail(
            new List<Messaging.SingleEmailMessage>{ mail }
        );

        Task auditTask = new Task();

        auditTask.WhatId = parentId;
        auditTask.Subject = 'Conflict Notification Sent';
        auditTask.Status = 'Completed';
        auditTask.Priority = 'Normal';
        auditTask.ActivityDate = Date.today();
        auditTask.Description =
            'Email sent to: ' + String.join(emails, ', ');

        insert auditTask;

    } catch (Exception e) {

        throw new AuraHandledException(
            'sendConflictAlert error: ' + e.getMessage()
        );
    }
  }
}