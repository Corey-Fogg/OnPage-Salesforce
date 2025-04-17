@RestResource(urlMapping='/onpagecallback/*')
global without sharing class OnPageCallbackController {
    @HttpPost
    global static void handleCallback() {
        RestRequest req = RestContext.request;
        String body = req.requestBody.toString();
        System.debug('Incoming Webhook Payload: ' + body);
        try {
            Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(body);
            String externalId = ((String) payload.get('externalId')).trim();
            Map<String, Object> account = (Map<String, Object>) payload.get('account');
            Map<String, Object> status = (Map<String, Object>) payload.get('status');
            String firstName = (String) account.get('firstName');
            String lastName = (String) account.get('lastName');
            String opid = String.valueOf(account.get('opid'));
            String statusType = (String) status.get('type');
            String statusText = (String) status.get('text');

            String formattedUpdate = firstName + ' ' + lastName + ' - (' + opid + '): ' + statusType;
            if (!String.isBlank(statusText)) {
                formattedUpdate += ' ' + statusText;
            }

            List<Case> cases;
            try {
                Id caseId = Id.valueOf(externalId);
                cases = [SELECT Id, OnPage_Updates__c, OnPage_Message_ID__c FROM Case WHERE Id = :caseId LIMIT 1];
            } catch (Exception e) {
                cases = [SELECT Id, OnPage_Updates__c, OnPage_Message_ID__c FROM Case WHERE CaseNumber = :externalId LIMIT 1];
            }

            if (!cases.isEmpty()) {
                Case c = cases[0];
                String current = c.OnPage_Updates__c;
                if (!String.isBlank(current)) {
                    current += '\n';
                } else {
                    current = '';
                }
                c.OnPage_Updates__c = current + formattedUpdate;
                c.OnPage_Message_ID__c = String.valueOf(payload.get('messageId'));
                update c;
            }
        } catch (Exception e) {
            System.debug('ERROR during callback processing: ' + e.getMessage());
        }
    }
}
