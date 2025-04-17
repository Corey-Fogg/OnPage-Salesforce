public class SendOnPagePageFlowAction {
    public class Input {
        @InvocableVariable(required=true) public Id recordId;
        @InvocableVariable(required=true) public String recipientId;
        @InvocableVariable public String callbackUri;
        @InvocableVariable public String subject;
        @InvocableVariable public String body;
        @InvocableVariable public String priority; // Expecting "HIGH" or "LOW"
    }

    public class Output {
        @InvocableVariable public String messageId;
        @InvocableVariable public String status;
    }

    @InvocableMethod(label='Send OnPage Page' description='Send an OnPage alert with optional callback')
    public static List<Output> send(List<Input> requests) {
        System.debug('Starting SendOnPagePageFlowAction.send with ' + requests.size() + ' request(s)');
        List<Output> results = new List<Output>();
        for (Input req : requests) {
            sendPageAsync(req.recordId, req.recipientId, req.callbackUri, req.subject, req.body, req.priority);
            Output result = new Output();
            result.status = 'Dispatched to Async';
            results.add(result);
        }
        return results;
    }

    @future(callout=true)
    public static void sendPageAsync(Id recordId, String recipientId, String callbackUri, String subject, String body, String priority) {
        try {
            System.debug('Looking up Case for Id: ' + recordId);
            Case c = [SELECT Id, Subject, Description, CaseNumber FROM Case WHERE Id = :recordId LIMIT 1];
            String token = OnPage_Settings__mdt.getInstance('Default').Bearer_Token__c;
            String callback = String.isBlank(callbackUri)
                ? OnPage_Settings__mdt.getInstance('Default').Default_Callback_URL__c
                : callbackUri;

            // Check if a page already exists for this CaseNumber
            HttpRequest checkReq = new HttpRequest();
            checkReq.setEndpoint('https://rest.onsetmobile.com/pages?externalId=' + EncodingUtil.urlEncode(c.CaseNumber, 'UTF-8'));
            checkReq.setMethod('GET');
            checkReq.setHeader('Authorization', 'Bearer ' + token);
            Http checkHttp = new Http();
            HttpResponse checkRes = checkHttp.send(checkReq);

            if (checkRes.getStatusCode() == 200) {
                List<Object> existingPages = (List<Object>) ((Map<String, Object>) JSON.deserializeUntyped(checkRes.getBody())).get('pages');
                if (!existingPages.isEmpty()) {
                    System.debug('Page already exists for CaseNumber ' + c.CaseNumber + ', skipping creation.');
                    return;
                }
            }

            // Build case link
            String baseUrl = URL.getOrgDomainUrl().toExternalForm();
            String caseLink = baseUrl + '/' + c.Id;
            String fullBody = (String.isBlank(body) ? c.Description : body) + '\n\nView Case: ' + caseLink;

            Map<String, Object> pagePayload = new Map<String, Object>{
                'externalId' => c.CaseNumber,
                'subject' => String.isBlank(subject) ? c.Subject : subject,
                'body' => fullBody,
                'recipients' => new List<String>{ recipientId },
                'callbackUri' => callback,
                'allowFreeTextReplies' => true
            };

            if (priority != null && (priority == 'HIGH' || priority == 'LOW')) {
                pagePayload.put('priority', priority);
            }

            HttpRequest httpReq = new HttpRequest();
            httpReq.setEndpoint('https://rest.onsetmobile.com/pages');
            httpReq.setMethod('POST');
            httpReq.setHeader('Authorization', 'Bearer ' + token);
            httpReq.setHeader('Content-Type', 'application/json');
            httpReq.setBody(JSON.serialize(pagePayload));

            System.debug('Prepared HTTP Request: ' + JSON.serialize(pagePayload));
            Http http = new Http();
            HttpResponse res = http.send(httpReq);
            System.debug('HTTP Response: ' + res.getBody());
            System.debug('HTTP Status: ' + res.getStatusCode());

            if (res.getStatusCode() == 200 || res.getStatusCode() == 202) {
                Map<String, Object> resBody = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                c.OnPage_Message_ID__c = String.valueOf(resBody.get('messageId'));
                update c;
            }
        } catch (Exception e) {
            System.debug('Exception during sendPageAsync: ' + e.getMessage());
        }
    }
}
