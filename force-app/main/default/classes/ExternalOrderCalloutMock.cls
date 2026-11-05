/**
 * @description HTTP Callout Mock implementation for ExternalOrderCalloutService unit tests.
 * Simulates an external ERP / REST API returning 200 OK with order confirmation JSON.
 */
@isTest
public class ExternalOrderCalloutMock implements HttpCalloutMock {

    private Integer statusCode;
    private String responseBody;

    public ExternalOrderCalloutMock() {
        this(200, '{"status": "SUCCESS", "message": "Order received successfully", "externalOrderId": "EXT-ORD-98231"}');
    }

    public ExternalOrderCalloutMock(Integer statusCode, String responseBody) {
        this.statusCode = statusCode;
        this.responseBody = responseBody;
    }

    public HttpResponse respond(HttpRequest req) {
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');
        res.setBody(this.responseBody);
        res.setStatusCode(this.statusCode);
        res.setStatus(this.statusCode == 200 ? 'OK' : 'Error');
        return res;
    }
}

