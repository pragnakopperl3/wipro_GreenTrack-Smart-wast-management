public with sharing class GreenTrackComplaintService {

    /**
     * Returns SLA target hours based on severity level.
     * Critical: 4 hours, High: 12 hours, Medium: 24 hours, Low: 48 hours.
     */
    public static Integer getSlaHours(String severity) {
        if (String.isBlank(severity)) {
            return 24;
        }
        switch on severity {
            when 'Critical' { return 4; }
            when 'High' { return 12; }
            when 'Medium' { return 24; }
            when 'Low' { return 48; }
            when else { return 24; }
        }
    }

    /**
     * Calculates Due Date from reported date and SLA hours.
     */
    public static Date calculateDueDate(DateTime reportedDate, Integer slaHours) {
        DateTime baseDate = reportedDate != null ? reportedDate : System.now();
        DateTime targetDateTime = baseDate.addHours(slaHours);
        return targetDateTime.date();
    }

    /**
     * Resolves a complaint by setting status, resolution date, and notes.
     */
    public static Waste_Complaint__c resolveComplaint(Id complaintId, String resolutionNotes) {
        if (complaintId == null) {
            throw new IllegalArgumentException('Complaint ID cannot be null.');
        }

        Waste_Complaint__c complaint = [
            SELECT Id, Status__c, Resolution_Date__c, Resolution_Notes__c, Resident__c, Complaint_Type__c, Location__c
            FROM Waste_Complaint__c
            WHERE Id = :complaintId
            LIMIT 1
        ];

        complaint.Status__c = 'Resolved';
        complaint.Resolution_Date__c = System.now();
        complaint.Resolution_Notes__c = String.isNotBlank(resolutionNotes) ? resolutionNotes : 'Complaint resolved by service team.';

        update complaint;
        return complaint;
    }

    /**
     * Returns aggregate statistics on waste complaints.
     */
    public static Map<String, Object> getComplaintStatistics() {
        Map<String, Object> stats = new Map<String, Object>();

        // Total complaints
        Integer totalComplaints = [SELECT COUNT() FROM Waste_Complaint__c];
        stats.put('totalComplaints', totalComplaints);

        // Open complaints
        Integer openComplaints = [SELECT COUNT() FROM Waste_Complaint__c WHERE Status__c NOT IN ('Resolved', 'Closed')];
        stats.put('openComplaints', openComplaints);

        // Resolved complaints
        Integer resolvedComplaints = [SELECT COUNT() FROM Waste_Complaint__c WHERE Status__c = 'Resolved'];
        stats.put('resolvedComplaints', resolvedComplaints);

        // By Severity
        Map<String, Integer> bySeverity = new Map<String, Integer>();
        for (AggregateResult ar : [SELECT Severity__c sev, COUNT(Id) cnt FROM Waste_Complaint__c GROUP BY Severity__c]) {
            String sev = (String) ar.get('sev');
            if (String.isNotBlank(sev)) {
                bySeverity.put(sev, ((Decimal) ar.get('cnt')).intValue());
            }
        }
        stats.put('bySeverity', bySeverity);

        // By Location
        Map<String, Integer> byLocation = new Map<String, Integer>();
        for (AggregateResult ar : [SELECT Location__c loc, COUNT(Id) cnt FROM Waste_Complaint__c GROUP BY Location__c]) {
            String loc = (String) ar.get('loc');
            if (String.isNotBlank(loc)) {
                byLocation.put(loc, ((Decimal) ar.get('cnt')).intValue());
            }
        }
        stats.put('byLocation', byLocation);

        return stats;
    }

    /**
     * Retrieves overdue complaints breaching SLA.
     */
    public static List<Waste_Complaint__c> getOverdueComplaints() {
        return [
            SELECT Id, Name, Resident__c, Complaint_Type__c, Location__c, Severity__c, Status__c, Due_Date__c, Assigned_Team__c
            FROM Waste_Complaint__c
            WHERE Due_Date__c < :Date.today()
              AND Status__c NOT IN ('Resolved', 'Closed')
            ORDER BY Due_Date__c ASC
        ];
    }
}