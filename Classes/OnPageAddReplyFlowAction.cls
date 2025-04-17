public class OnPageAddReplyFlowAction {
    public class Output {
        @InvocableVariable public String status;
    }

    @InvocableMethod(label='Add OnPage Reply' description='Post a reply to an existing OnPage message from a Case Comment')
    public static void reply(List<Id> commentIds) {
        for (Id commentId : commentIds) {
            sendReplyAsync(commentId);
        }
    }

    @future(callout=true)
    public static void sendReplyAsync(Id commentId) {
        try {
            CaseComment comment = [
                SELECT Id, CommentBody, ParentId,
                    Parent.OnPage_Message_ID__c
                FROM CaseComment
                WHERE Id = :commentId
                LIMIT 1
            ];

            String replyBody = comment.CommentBody;
            String onPageMessageId = comment.Parent.OnPage_Message_ID__c;

            System.debug('Found Comment Body: ' + replyBody);
            System.debug('Linked OnPage Message ID: ' + onPageMessageId);

            if (String.isBlank(onPageMessageId)) {
                System.debug('No OnPage Message ID found on parent Case');
                return;
            }

            String token = OnPage_Settings__mdt.getInstance('Default').Bearer_Token__c;

            Map<String, Object> payload = new Map<String, Object>{
                'replyToPageId' => onPageMessageId,
                'body' => replyBody
            };

            HttpRequest reqHttp = new HttpRequest();
            reqHttp.setEndpoint('https://rest.onsetmobile.com/pageReply');
            reqHttp.setMethod('POST');
            reqHttp.setHeader('Authorization', 'Bearer ' + token);
            reqHttp.setHeader('Content-Type', 'application/json');
            reqHttp.setBody(JSON.serialize(payload));

            Http http = new Http();
            HttpResponse res = http.send(reqHttp);

            System.debug('HTTP Response Status: ' + res.getStatusCode());
            System.debug('HTTP Response Body: ' + res.getBody());
        } catch (Exception e) {
            System.debug('Exception while sending OnPage reply: ' + e.getMessage());
        }
    }
}
