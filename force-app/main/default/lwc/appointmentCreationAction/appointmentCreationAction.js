import { LightningElement, api } from 'lwc';
import createAppointmentFromModal from '@salesforce/apex/AppointmentController.createAppointmentFromModal';

const SLOT_HOURS = [
    9, 10, 11, 12, 13,
    14, 15, 16, 17, 18
];

function fmt12(hour) {
    const suffix = hour >= 12 ? 'PM' : 'AM';
    const h = hour % 12 || 12;
    return `${h}:00 ${suffix}`;
}

export default class CpBookingAppointment extends LightningElement {

    // Record Id from the Quick Action
    @api recordId;

    formDate = '';
    formStartTime = null;
    formNotes = '';

    isBooking = false;

    bookingSuccess = false;
    bookingError = '';

    dateError = '';
    timeError = '';

    connectedCallback() {
        this.formDate = this.getTodayLocalDate();
    }

    get todayDate() {
        return this.getTodayLocalDate();
    }

    get formEndTimeLabel() {
        if (this.formStartTime === null) {
            return '';
        }

        return fmt12(this.formStartTime + 1);
    }

    get dateInputClass() {
        return this.dateError
            ? 'input input-error'
            : 'input';
    }

    get timeSlots() {
        return SLOT_HOURS.map(hour => ({
            value: hour,
            label: fmt12(hour),
            className:
                this.formStartTime === hour
                    ? 'time-slot selected'
                    : 'time-slot'
        }));
    }

    getTodayLocalDate() {
        const today = new Date();

        const year = today.getFullYear();
        const month = String(today.getMonth() + 1).padStart(2, '0');
        const day = String(today.getDate()).padStart(2, '0');

        return `${year}-${month}-${day}`;
    }

    handleDateChange(event) {
        this.formDate = event.target.value;
        this.dateError = '';
        this.bookingError = '';
    }

    handleTimeSelect(event) {
        this.formStartTime =
            Number(event.currentTarget.dataset.hour);

        this.timeError = '';
        this.bookingError = '';
    }

    handleNotesChange(event) {
        this.formNotes = event.target.value;
    }

    async submitBooking() {

        this.dateError = '';
        this.timeError = '';
        this.bookingError = '';

        let isValid = true;

        // Validate date
        if (!this.formDate) {
            this.dateError = 'Please select a date.';
            isValid = false;
        } else if (this.formDate < this.todayDate) {
            this.dateError = 'Please select a future date.';
            isValid = false;
        }

        // Validate time
        if (this.formStartTime === null) {
            this.timeError = 'Please select a time.';
            isValid = false;
        }

        if (!isValid) {
            return;
        }

        // Make sure Quick Action has a record
        if (!this.recordId) {
            this.bookingError =
                'Unable to identify the enquiry. Please try again.';
            return;
        }

        this.isBooking = true;

        try {

            await createAppointmentFromModal({
                leadId: this.recordId,
                dateStr: this.formDate,
                startHour: this.formStartTime,
                endHour: this.formStartTime + 1,
                utcOffsetMinutes:
                    -new Date().getTimezoneOffset(),
                notes: this.formNotes
            });

            this.bookingSuccess = true;

            // Close Salesforce Quick Action after success
            setTimeout(() => {
                this.closeAction();
            }, 1200);

        } catch (error) {

            this.bookingError =
                error?.body?.message ||
                'Something went wrong. Please try again.';

        } finally {
            this.isBooking = false;
        }
    }

    closeAction() {

        this.dispatchEvent(
            new CustomEvent('close')
        );

        // Salesforce Quick Action close
        this.dispatchEvent(
            new CustomEvent('closeaction')
        );
    }
}