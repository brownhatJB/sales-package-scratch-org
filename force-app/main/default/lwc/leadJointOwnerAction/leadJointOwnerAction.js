import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import LightningConfirm from 'lightning/confirm';

import getInitialData
    from '@salesforce/apex/LeadJointOwnerController.getInitialData';

import saveOwners
    from '@salesforce/apex/LeadJointOwnerController.saveOwners';

export default class LeadJointOwnerAction extends LightningElement {
    _recordId;
    loadStarted = false;
    nextLocalId = 0;

    owners = [];
    deletedOwnerIds = [];
    customerTypeValues = [];
    buyerType;

    isLoading = true;
    isSaving = false;
    loadError;

    // --------------------------------------------------
    // Record ID
    // --------------------------------------------------

    @api
    get recordId() {
        return this._recordId;
    }

    set recordId(value) {
        this._recordId = value;

        if (value && !this.loadStarted) {
            this.loadStarted = true;
            this.loadData();
        }
    }

    // --------------------------------------------------
    // Initial Data
    // --------------------------------------------------

    async loadData() {
        this.isLoading = true;
        this.loadError = undefined;

        try {
            const data = await getInitialData({
                leadId: this.recordId
            });

            this.buyerType = data.buyerType;
            this.customerTypeValues = (
                data.customerTypeValues || []
            ).map((item) => {
                // Supports Apex returning either strings or
                // combobox-compatible label/value objects.
                if (typeof item === 'string') {
                    return {
                        label: item,
                        value: item
                    };
                }

                return item;
            });

            this.owners = (data.owners || []).map((owner) => ({
                id: owner.id,
                clientKey: owner.id || this.createClientKey(),
                customerContactId: owner.customerContactId || null,
                customerType: owner.customerType || '',
                ownershipOrder: Number(owner.ownershipOrder),
                ownershipPercentage:
                    owner.ownershipPercentage == null
                        ? null
                        : Number(owner.ownershipPercentage),
                isPrimary: Boolean(owner.isPrimary)
            }));

            this.normalizeOrders();
        } catch (error) {
            this.loadError = this.getErrorMessage(error);

            this.showToast(
                'Error loading joint owners',
                this.loadError,
                'error'
            );
        } finally {
            this.isLoading = false;
        }
    }

    createClientKey() {
        this.nextLocalId += 1;
        return `new-owner-${this.nextLocalId}`;
    }

    // --------------------------------------------------
    // Getters
    // --------------------------------------------------

    get hasOwners() {
        return this.owners.length > 0;
    }

    get ownerCount() {
        return this.owners.length;
    }

    get primaryCount() {
        return this.owners.filter(
            (owner) => owner.isPrimary
        ).length;
    }

    get hasInvalidPrimaryCount() {
        return this.hasOwners && this.primaryCount !== 1;
    }

    get totalPercentage() {
        return this.owners.reduce((total, owner) => {
            const percentage = Number(owner.ownershipPercentage);

            return total + (
                Number.isFinite(percentage) ? percentage : 0
            );
        }, 0);
    }

    get percentageIsValid() {
        return Math.abs(this.totalPercentage - 100) < 0.000001;
    }

    get allocationIcon() {
        return this.percentageIsValid
            ? 'utility:success'
            : 'utility:warning';
    }

    get allocationStyle() {
        const progress = Math.max(
            0,
            Math.min(this.totalPercentage, 100)
        );

        return `width: ${progress}%;`;
    }

    get allocationMessage() {
        if (!this.hasOwners) {
            return 'Add owners and allocate ownership percentages.';
        }

        if (this.percentageIsValid) {
            return 'Ownership allocation totals 100%.';
        }

        const difference = 100 - this.totalPercentage;

        if (difference > 0) {
            return `Allocate another ${difference.toFixed(2)}% to reach 100%.`;
        }

        return `Reduce the allocation by ${Math.abs(difference).toFixed(2)}% to reach 100%.`;
    }

    get displayOwners() {
        return this.owners.map((owner) => ({
            ...owner,
            removeDisabled:
                this.isSaving ||
                (owner.isPrimary && this.owners.length > 1),
            percentageInput:
                owner.ownershipPercentage == null
                    ? ''
                    : owner.ownershipPercentage,
            orderInput: owner.ownershipOrder
        }));
    }

    get saveLabel() {
        return this.isSaving ? 'Saving...' : 'Save Owners';
    }

    get saveDisabled() {
        return !this.canSave;
    }

    get canSave() {
        if (this.isLoading || this.isSaving || this.loadError) {
            return false;
        }

        // Empty list is valid only when existing records are
        // being deleted. Apex will change Buyer Type to Individual.
        if (!this.hasOwners) {
            return this.deletedOwnerIds.length > 0;
        }

        if (this.primaryCount !== 1 || !this.percentageIsValid) {
            return false;
        }

        const orders = this.owners.map(
            (owner) => Number(owner.ownershipOrder)
        );

        const validOrders = orders.every(
            (order) =>
                Number.isInteger(order) && order >= 1
        );

        if (!validOrders) {
            return false;
        }

        const uniqueOrders = new Set(orders);

        if (uniqueOrders.size !== this.owners.length) {
            return false;
        }

        const expectedOrders = Array.from(
            { length: this.owners.length },
            (_, index) => index + 1
        );

        if (
            !expectedOrders.every((order) =>
                uniqueOrders.has(order)
            )
        ) {
            return false;
        }

        const primaryOwner = this.owners.find(
            (owner) => owner.isPrimary
        );

        if (!primaryOwner || primaryOwner.ownershipOrder !== 1) {
            return false;
        }

        return this.owners.every((owner) => {
            const percentage = Number(owner.ownershipPercentage);

            return (
                Boolean(owner.customerContactId) &&
                Boolean(owner.customerType) &&
                Number.isFinite(percentage) &&
                percentage > 0 &&
                percentage <= 100
            );
        });
    }

    // --------------------------------------------------
    // Add Owner
    // --------------------------------------------------

    handleAddOwner() {
        if (this.isSaving) {
            return;
        }

        const isFirstOwner = this.owners.length === 0;

        const newOwner = {
            id: null,
            clientKey: this.createClientKey(),
            customerContactId: null,
            customerType: '',
            ownershipOrder: this.owners.length + 1,
            ownershipPercentage: null,
            isPrimary: isFirstOwner
        };

        this.owners = [...this.owners, newOwner];
        this.normalizeOrders();
    }

    // --------------------------------------------------
    // Contact Record Picker
    // --------------------------------------------------

    handleContactChange(event) {
        const ownerId = event.currentTarget.dataset.id;
        const contactId = event.detail.recordId || null;

        this.owners = this.owners.map((owner) => {
            if (owner.clientKey === ownerId) {
                return {
                    ...owner,
                    customerContactId: contactId
                };
            }

            return owner;
        });
    }

    // --------------------------------------------------
    // Owner Field Changes
    // --------------------------------------------------

    handleFieldChange(event) {
        const ownerId = event.currentTarget.dataset.id;
        const field = event.currentTarget.dataset.field;

        let value = event.detail?.value;

        if (value === undefined) {
            value = event.currentTarget.value;
        }

        if (field === 'ownershipPercentage') {
            value = value === '' || value == null
                ? null
                : Number(value);
        }

        if (field === 'ownershipOrder') {
            value = value === '' || value == null
                ? null
                : Number(value);
        }

        this.owners = this.owners.map((owner) => {
            if (owner.clientKey === ownerId) {
                return {
                    ...owner,
                    [field]: value
                };
            }

            return owner;
        });

        if (field === 'ownershipOrder') {
            this.reorderByRequestedOrder();
        }
    }

    // --------------------------------------------------
    // Set Primary Owner
    // --------------------------------------------------

    handleSetPrimary(event) {
        if (this.isSaving) {
            return;
        }

        const ownerId = event.currentTarget.dataset.id;

        const selectedOwner = this.owners.find(
            (owner) => owner.clientKey === ownerId
        );

        if (!selectedOwner || selectedOwner.isPrimary) {
            return;
        }

        const updatedOwner = {
            ...selectedOwner,
            isPrimary: true
        };

        const otherOwners = this.owners
            .filter((owner) => owner.clientKey !== ownerId)
            .map((owner) => ({
                ...owner,
                isPrimary: false
            }));

        this.owners = [updatedOwner, ...otherOwners];

        this.normalizeOrders();
    }

    // --------------------------------------------------
    // Remove Owner
    // --------------------------------------------------

    async handleRemoveOwner(event) {
        if (this.isSaving) {
            return;
        }

        const ownerId = event.currentTarget.dataset.id;

        const ownerToRemove = this.owners.find(
            (owner) => owner.clientKey === ownerId
        );

        if (!ownerToRemove) {
            return;
        }

        // A primary owner cannot be removed while other owners remain.
        if (ownerToRemove.isPrimary && this.owners.length > 1) {
            this.showToast(
                'Primary owner required',
                'Select another owner as primary before removing this owner.',
                'warning'
            );

            return;
        }

        // If this is the sole existing primary owner, confirm the
        // transition to Individual before allowing removal.
        if (
            ownerToRemove.isPrimary &&
            this.owners.length === 1 &&
            ownerToRemove.id
        ) {
            const confirmed = await LightningConfirm.open({
                label: 'Remove Primary Owner',
                message:
                    'This is the only joint owner. Removing it will change the Lead Buyer Type to Individual. Do you want to continue?',
                theme: 'warning'
            });

            if (!confirmed) {
                return;
            }
        }

        if (ownerToRemove.id) {
            this.deletedOwnerIds = [
                ...new Set([
                    ...this.deletedOwnerIds,
                    ownerToRemove.id
                ])
            ];
        }

        this.owners = this.owners.filter(
            (owner) => owner.clientKey !== ownerId
        );

        this.normalizeOrders();
    }

    // --------------------------------------------------
    // Ordering
    // --------------------------------------------------

    reorderByRequestedOrder() {
        const primaryOwner = this.owners.find(
            (owner) => owner.isPrimary
        );

        const otherOwners = this.owners
            .filter((owner) => !owner.isPrimary)
            .sort((a, b) => {
                const orderA = Number(a.ownershipOrder);
                const orderB = Number(b.ownershipOrder);

                const safeA = Number.isFinite(orderA)
                    ? orderA
                    : Number.MAX_SAFE_INTEGER;

                const safeB = Number.isFinite(orderB)
                    ? orderB
                    : Number.MAX_SAFE_INTEGER;

                return safeA - safeB;
            });

        this.owners = primaryOwner
            ? [primaryOwner, ...otherOwners]
            : otherOwners;

        this.normalizeOrders();
    }

    normalizeOrders() {
        const primaryOwner = this.owners.find(
            (owner) => owner.isPrimary
        );

        const otherOwners = this.owners.filter(
            (owner) => !owner.isPrimary
        );

        const orderedOwners = primaryOwner
            ? [primaryOwner, ...otherOwners]
            : [...otherOwners];

        this.owners = orderedOwners.map((owner, index) => ({
            ...owner,
            ownershipOrder: index + 1,
            isPrimary: index === 0 && Boolean(primaryOwner)
        }));
    }

    // --------------------------------------------------
    // Save
    // --------------------------------------------------

    async handleSave() {
        if (!this.canSave) {
            this.showToast(
                'Cannot save',
                'Check the Contact, customer type, ownership order, primary owner, and 100% ownership allocation.',
                'error'
            );

            return;
        }

        this.isSaving = true;

        try {
            const ownersToSave = this.owners.map((owner) => ({
                id: owner.id || null,
                customerContactId: owner.customerContactId,
                customerType: owner.customerType,
                ownershipOrder: owner.ownershipOrder,
                ownershipPercentage: owner.ownershipPercentage,
                isPrimary: owner.isPrimary
            }));

            const result = await saveOwners({
                leadId: this.recordId,
                ownersJson: JSON.stringify(ownersToSave),
                deletedOwnerIds: this.deletedOwnerIds
            });

            this.showToast(
                'Success',
                result?.message || 'Joint owners saved successfully.',
                'success'
            );

            this.dispatchEvent(new CloseActionScreenEvent());
        } catch (error) {
            this.showToast(
                'Error saving joint owners',
                this.getErrorMessage(error),
                'error'
            );
            console.error('Error saving joint owners:', error);
        } finally {
            this.isSaving = false;
        }
    }

    // --------------------------------------------------
    // Cancel
    // --------------------------------------------------

    handleCancel() {
        if (this.isSaving) {
            return;
        }

        this.dispatchEvent(new CloseActionScreenEvent());
    }

    // --------------------------------------------------
    // Utility
    // --------------------------------------------------

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }

    getErrorMessage(error) {
        if (error?.body?.message) {
            return error.body.message;
        }

        if (Array.isArray(error?.body)) {
            return error.body
                .map((item) => item.message)
                .join(', ');
        }

        return error?.message || 'An unexpected error occurred.';
    }
}