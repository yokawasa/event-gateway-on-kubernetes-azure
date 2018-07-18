/**
* Echo function that simply receives CloudEvent formatted requests and return
* exactlly the same body message as it receives
* 
* [Assumption]
* The echo function assumes that it recives requests which are CloudEvent formatted like this: 
* { 
*    eventType: 'http',
*    cloudEventsVersion: '0.1',
*    source: 'https://serverless.com/event-gateway/#transformationVersion=0.1',
*    eventID: 'fbbe85e2-1526-425b-86b0-23dfaedf4ec3',
*    eventTime: '2018-07-18T14:41:36.483453919Z',
*    contentType: 'application/json',
*    data: 
*    { 
*        headers:{},
*        query: {},
*        body: { message: 'Hello world!' },
*        host: '40.117.129.57:4000',
*        path: '/',
*        method: 'POST',
*        params: null 
*    } 
* }
*/
module.exports = function (context, req) {
    context.log('JavaScript HTTP trigger function processed a request.');

    var headers = new Object();
    headers['Compute-Type'] = 'function';

    context.res = {
        // status: 200, /* Defaults to 200 */
        body: {
            body: JSON.stringify(req.body.data.body),
            headers: headers,
            statusCode: 200
        }
    };
    context.done();
};

