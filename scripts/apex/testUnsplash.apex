HttpRequest request = new HttpRequest();
request.setEndpoint(
    'callout:Unsplash_API/search/photos' +
    '?query=laptop' +
    '&per_page=1' +
    '&orientation=landscape' +
    '&content_filter=high'
);
request.setMethod('GET');

HttpResponse response = new Http().send(request);

System.debug('STATUS: ' + response.getStatusCode());
System.debug('BODY: ' + response.getBody());
