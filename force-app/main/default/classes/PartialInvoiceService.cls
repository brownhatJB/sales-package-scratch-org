public class PartialInvoiceService {

    // --- INPUTS FROM FLOW ---
    public class InvoiceRequest {
        @InvocableVariable(label='Record ID (Offer PPI or PPI)' required=true description='Pass the recordId from the Screen Flow')
        public Id recordId;
        
        @InvocableVariable(label='Input Amount' required=true description='The amount entered by the user in the Flow')
        public Decimal amount;
    }

    // --- OUTPUTS TO FLOW ---
    public class InvoiceResult {
        @InvocableVariable(label='Is Success')
        public Boolean isSuccess;
        
        @InvocableVariable(label='Message (Error or Success)')
        public String message;
        
        @InvocableVariable(label='New Invoice ID')
        public Id invoiceId;
    }

    @InvocableMethod(label='Generate Partial Invoice' description='Creates a Partial Invoice and updates the Invoiced Amount on the parent Installment.')
    public static List<InvoiceResult> generatePartialInvoices(List<InvoiceRequest> requests) {
        List<InvoiceResult> results = new List<InvoiceResult>();
        
        // 1. Separate the IDs based on their Object Type
        Set<Id> offerPpiIds = new Set<Id>();
        Set<Id> ppiIds = new Set<Id>();
        
        for (InvoiceRequest req : requests) {
            if (req.recordId != null) {
                String objName = req.recordId.getSObjectType().getDescribe().getName();
                
                if (objName.containsIgnoreCase('Offer_Payment_Plan_Item__c')) {
                    offerPpiIds.add(req.recordId);
                } else if (objName.containsIgnoreCase('Payment_Plan_Item__c')) {
                    ppiIds.add(req.recordId);
                }
            }
        }
        
        // 2. Query the current Invoiced Amount
        Map<Id, SObject> recordsMap = new Map<Id, SObject>();
        
        if (!offerPpiIds.isEmpty()) {
            String query = 'SELECT Id, Invoiced_Amount__c, Amount__c, Offer__c, Tax_Amount__c, Amount_Excl_Tax__c, Tentative_Due_Date__c, ' + 
                		   'Offer__r.Unit_Sale__c, Offer__r.Unit__c, Offer__r.Project__c, Offer__r.Properties__c, Offer__r.Account__c, Offer__r.Contact__c ' +
                           'FROM Offer_Payment_Plan_Item__c WHERE Id IN :offerPpiIds';
            for(SObject obj : Database.query(query)) { recordsMap.put(obj.Id, obj); }
        }
        if (!ppiIds.isEmpty()) {
            String query = 'SELECT Id, Invoiced_Amount__c, Amount__c, Offer__c, Customer_Account__c, Contact__c, Unit_Sale__c, Tax_Amount__c, Total_Amount_Excluding_Tax__c, Actual_Due_Date__c, ' +
                			'Unit_Sale__r.Project__c, Unit_Sale__r.Property__c, Unit_Sale__r.Unit__c ' +
                			'FROM Payment_Plan_Item__c WHERE Id IN :ppiIds';
            for(SObject obj : Database.query(query)) { recordsMap.put(obj.Id, obj); }
        }
        
        List<SObject> recordsToUpdate = new List<SObject>();
        List<Invoice__c> invoicesToInsert = new List<Invoice__c>();
        Map<Integer, Invoice__c> requestIndexToInvoiceMap = new Map<Integer, Invoice__c>();
        
        // 3. Process each request
        for (Integer i = 0; i < requests.size(); i++) {
            InvoiceRequest req = requests[i];
            InvoiceResult res = new InvoiceResult();
            res.isSuccess = false;
            
            // Basic Amount Validation
            if (req.amount == null || req.amount <= 0) {
                res.message = 'Error: The invoice amount must be greater than zero.';
                results.add(res);
                continue;
            }
            
            SObject record = recordsMap.get(req.recordId);
            if (record == null) {
                res.message = 'Error: Could not find the Installment record.';
                results.add(res);
                continue;
            }
            
            // Safely get current invoiced value (Treat null as 0)
            Decimal currentInvoiced = (Decimal)record.get('Invoiced_Amount__c');
            currentInvoiced = currentInvoiced != null ? currentInvoiced : 0;
            
            Decimal totalInstallmentAmount = (Decimal)record.get('Amount__c');
            totalInstallmentAmount = totalInstallmentAmount != null ? totalInstallmentAmount : 0;
            
            Decimal remainingAmount = totalInstallmentAmount - currentInvoiced;
            
            if (req.amount >= remainingAmount) {
                res.message = 'Error: You cannot invoice the entire remaining amount (' + remainingAmount + ') using the Partial Invoice tool. Please use the Full Invoice process instead.';
                results.add(res);
                continue;
            }
            
            // ==========================================
            // CALCULATE PARTIAL TAX AND EXCL. TAX
            // ==========================================
            
            Decimal sourceTaxAmount =
                (Decimal) record.get('Tax_Amount__c');
            
            Decimal sourceAmountExclTax;
            
            String objName =
                req.recordId.getSObjectType().getDescribe().getName();
            
            if (objName.containsIgnoreCase(
                    'Offer_Payment_Plan_Item__c')) {
            
                sourceAmountExclTax =
                    (Decimal) record.get('Amount_Excl_Tax__c');
            
            } else {
            
                sourceAmountExclTax =
                    (Decimal) record.get(
                        'Total_Amount_Excluding_Tax__c'
                    );
            }
            
            sourceTaxAmount =
                sourceTaxAmount != null ? sourceTaxAmount : 0;
            
            sourceAmountExclTax =
                sourceAmountExclTax != null ? sourceAmountExclTax : 0;
            
            Decimal partialTaxAmount;
            Decimal partialAmountExclTax;
            
            if (totalInstallmentAmount > 0) {
            
                Decimal taxRatio =
                    sourceTaxAmount / totalInstallmentAmount;
            
                partialTaxAmount =
                    (req.amount * taxRatio)
                    .setScale(2, RoundingMode.HALF_UP);
            
                partialAmountExclTax =
                    (req.amount - partialTaxAmount)
                    .setScale(2, RoundingMode.HALF_UP);
            
            } else {
            
                partialTaxAmount = 0;
                partialAmountExclTax = req.amount;
            }
            
            // 4. Create the Invoice Record
            Invoice__c newInv = new Invoice__c();
            newInv.Invoice_Amount__c = req.amount; 
            newInv.Part_Invoice__c = true;
            newInv.Status__c = 'Active';
            newInv.Invoice_Date__c = System.today();
            newInv.Tax_Value__c = partialTaxAmount;
			newInv.Total_Amount_Excluding_Tax__c = partialAmountExclTax;
            
            
            
            if (objName.containsIgnoreCase('Offer_Payment_Plan_Item__c')) {
                
                newInv.Offer_Payment_Plan_Item__c = req.recordId;
                
                // Offer PPI → Tentative Due Date
    			newInv.Actual_Due_Date__c = (Date) record.get('Tentative_Due_Date__c');
                
                
                Id offerId = (Id)record.get('Offer__c');
                if (offerId != null) {
                    newInv.Offer__c = offerId;
                    
                    SObject offerRec = record.getSObject('Offer__r');
                    if (offerRec != null) {
                        newInv.Account__c = (Id)offerRec.get('Account__c');
                        newInv.Contact__c = (Id)offerRec.get('Contact__c');
                        newInv.Properties__c = (Id)offerRec.get('Properties__c');
                        newInv.Project__c = (Id)offerRec.get('Project__c');
                        newInv.Units__c = (Id)offerRec.get('Unit__c');
                        newInv.Unit_Sale__c = (Id)offerRec.get('Unit_Sale__c');
                    }
                }
            } else {
                
                newInv.Payment_Plan_Item__c = req.recordId; 
              
                // Payment PPI → Actual Due Date
    			newInv.Actual_Due_Date__c = (Date) record.get('Actual_Due_Date__c');
                
                
                newInv.Account__c = (Id)record.get('Customer_Account__c');
                newInv.Contact__c = (Id)record.get('Contact__c');
                
                Id unitSaleId = (Id)record.get('Unit_Sale__c');
                if (unitSaleId != null) {
                    newInv.Unit_Sale__c = unitSaleId;
                    
                    SObject usRec = record.getSObject('Unit_Sale__r');
                    if (usRec != null) {
                        newInv.Project__c = (Id)usRec.get('Project__c');
                        newInv.Properties__c = (Id)usRec.get('Property__c');
                        newInv.Units__c = (Id)usRec.get('Unit__c');
                    }
                }
            }
            
            
            invoicesToInsert.add(newInv);
            requestIndexToInvoiceMap.put(i, newInv);
            
            // 5. Update the Parent Installment
            record.put('Invoiced_Amount__c', currentInvoiced + req.amount);
            record.put('Status__c', 'Partially Invoiced');
            record.put('Partial_Invoice_Generated__c', true);
            recordsToUpdate.add(record);
            
            res.isSuccess = true;
            res.message = 'Partial Invoice generated successfully!';
            results.add(res);
        }
        
        // 6. Execute Database Operations
        try {
            if (!invoicesToInsert.isEmpty()) {
                insert invoicesToInsert;
                for (Integer i : requestIndexToInvoiceMap.keySet()) {
                    results[i].invoiceId = requestIndexToInvoiceMap.get(i).Id;
                }
            }
            if (!recordsToUpdate.isEmpty()) {
                Map<Id, SObject> uniqueUpdates = new Map<Id, SObject>();
                uniqueUpdates.putAll(recordsToUpdate);
                for (SObject rec : recordsToUpdate) {
    System.debug('Status: ' + rec.get('Status__c'));
    System.debug('Invoiced Amount: ' + rec.get('Invoiced_Amount__c'));
}
                update uniqueUpdates.values();
            }
        } catch (Exception e) {
            for (InvoiceResult res : results) {
                res.isSuccess = false;
                res.message = 'Database Error: ' + e.getMessage();
            }
        }
        
        return results;
    }
}