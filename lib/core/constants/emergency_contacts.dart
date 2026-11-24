/// Emergency and support contacts shown on the "Get Help Now" screen.
///
/// IMPORTANT: The GMI Counselling Unit must verify every number and hour
/// below before each release. Do not add a number that has not been checked.
class EmergencyContact {
  const EmergencyContact({
    required this.name,
    required this.description,
    required this.availability,
    this.phone,
    this.isEmergency = false,
  });

  final String name;
  final String description;
  final String availability;

  /// Dialable number (digits only). `null` when the contact is in person.
  final String? phone;
  final bool isEmergency;
}

abstract final class EmergencyContacts {
  static const List<EmergencyContact> all = [
    EmergencyContact(
      name: 'Emergency Services (Police / Ambulance / Fire)',
      description: 'If you or someone else is in immediate danger.',
      availability: '24 hours',
      phone: '999',
      isEmergency: true,
    ),
    EmergencyContact(
      name: 'Emergency from a mobile phone',
      description: 'Works even when your phone has no credit.',
      availability: '24 hours',
      phone: '112',
      isEmergency: true,
    ),
    EmergencyContact(
      name: 'Befrienders Kuala Lumpur',
      description: 'Confidential emotional support from trained volunteers.',
      availability: '24 hours',
      phone: '0376272929',
    ),
    EmergencyContact(
      name: 'Talian HEAL (Ministry of Health)',
      description: 'Mental health psychosocial support line.',
      availability: 'Daily, 8:00 am – 12:00 midnight',
      phone: '15555',
    ),
    EmergencyContact(
      name: 'GMI Counselling Unit',
      description:
          'Talk to a GMI counsellor in person, or request an appointment in '
          'the Booking tab.',
      availability: 'Office hours (check with Student Affairs)',
    ),
  ];
}
