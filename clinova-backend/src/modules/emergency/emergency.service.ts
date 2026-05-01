import { Injectable } from '@nestjs/common';

@Injectable()
export class EmergencyService {
  triggerEmergency(lat: number, lng: number) {
    return {
      status: 'DISPATCH_NOTIFIED',
      nearestBranch: 'Clinova Central',
      emergencyPhone: '+97670110000',
      locationReceived: { lat, lng },
    };
  }
}
