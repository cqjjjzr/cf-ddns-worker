/**
 * This handled a request to update a given DNS record.
 * The request should have the following format:
 *
 * {"id": "<hmac token id>", "domain": "<subdomain>", "addr": "<addr, null for auto>", "type": "<ipv4 or ipv6>", timestamp: "<unix_timestamp>"}
 *
 * The request must contain the base64-encoded HMAC (of the request body) in the "Authorization" header
 */
import wcmatch from 'wildcard-match';
const Buffer = require('buffer/').Buffer
//const { subtle } = globalThis.crypto;
const subtle = crypto.subtle;

addEventListener("fetch", (event) => {
  event.respondWith(handleRequest(event.request));
});

/**
 * Handles the request and validates if changes should be made or not
 * @param {Request} request
 */
async function handleRequest(request) {
  if (request.method === "POST") {
    try {
      const requestBody = await request.text();
      await validateRequest(request, requestBody);
      const addr = request.headers.get("cf-connecting-ip");
      await updateRecord(addr, requestBody);
      return new Response("success", { status: 200 });
    } catch (e) {
      return new Response(e, { status: 401 });
    }
  }
  return new Response("invalid_request", { status: 401 });
}

/**
 * Checks if it is a valid and authentic request
 * @param {Request} request
 */
async function validateRequest(request, requestBody) {
  const window = 300; // 5 mins
  let bodyContent = {};
  try {
    bodyContent = JSON.parse(requestBody);
  } catch (e) {
    throw "invalid_json";
  }
  
  const token_id = bodyContent.id;
  const auth_dict = JSON.parse(Buffer.from(AUTH, "base64").toString());
  const auth_obj = auth_dict.find(it => it.id === token_id);
  if (!auth_obj)
    throw "invalid_uid";

  const signature = request.headers.get("authorization");
  if (!signature || !bodyContent.type)
    throw "missing_fields";
  
  if (bodyContent.type !== "ipv4" && bodyContent.type !== "ipv6")
    throw "malformed_object";

  if (!(await verifyHMAC(auth_obj.token, signature, requestBody)))
    throw "sign_failure";

  if (!wcmatch(auth_obj.allowed)(bodyContent.domain))
    throw "subdomain_not_allowed";

  const now = Math.floor(Date.now() / 1000);
  if (now < bodyContent.timestamp || now - bodyContent.timestamp > window)
    throw "timeout";
}

/**
 * Verifies the provided HMAC matches the message
 * @param {String} key
 * @param {String} signature
 * @param {String} message
 */
async function verifyHMAC(key, signature, message) {
  const keyImported = await subtle.importKey(
    "raw",
    Buffer.from(key),
    { name: "HMAC", hash: { name: "SHA-256" } },
    false,
    ["verify"]
  );

  return await subtle.verify(
    "HMAC",
    keyImported,
    Buffer.from(signature, "base64"),
    Buffer.from(message)
  );
}

/**
 * Updates the DNS record with the provided IP
 * @param {String} addr
 */
async function updateRecord(addr, requestBody) {
  const base = "https://api.cloudflare.com/client/v4/zones";
  const init = { headers: { Authorization: `Bearer ${CF_API_TOKEN}` } };
  const reqObj = JSON.parse(requestBody);
  const zone = ZONE_ID;
  
  addr = reqObj.addr ? reqObj.addr : addr;
  const type = reqObj.type === "ipv4" ? "A" : (reqObj.type === "ipv6" ? "AAAA" : null);
  if (!type)
    throw "invalid_type";
  
  const record_res = await fetch(
    `${base}/${zone}/dns_records?name=${reqObj.domain}&type=${type}`,
    init
  );
  if (!record_res.ok) 
    throw "fetch_record_failure"
  
  const records = (await record_res.json()).result;
  let upd_res;
  if (!records || records.length <= 0) {
    // create record
    init.method = "POST";
    init.body = JSON.stringify({ content: addr, type: type, name: reqObj.domain, ttl: 1 });
    upd_res = await fetch(`${base}/${zone}/dns_records`, init);
  } else {
    const record = records[0];
    if (record.content === addr)
      return;
    init.method = "PATCH";
    init.body = JSON.stringify({ content: addr });
    upd_res = await fetch(`${base}/${zone}/dns_records/${record.id}`, init);
  }
  
  if (!upd_res.ok)
    throw await upd_res.text();
}