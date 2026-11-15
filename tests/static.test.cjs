const fs=require('node:fs');
const vm=require('node:vm');
const assert=require('node:assert/strict');
const html=fs.readFileSync('marketplace.html','utf8');
const client=fs.readFileSync('supabase/client.js','utf8');
const sql=fs.readFileSync('supabase/migrations/20261115000000_initial_schema.sql','utf8');
const scripts=source=>[...source.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/g)].map(x=>x[1]).filter(Boolean);
for(const file of ['index.html','marketplace.html','find-homes.html']){
 for(const [index,script] of scripts(fs.readFileSync(file,'utf8')).entries()){
  new vm.Script(script,{filename:file+' inline script '+(index+1)});
 }
}
new vm.Script(client,{filename:'supabase/client.js'});
for(const method of ['homesquareLoadProperties','homesquareCreateDraft','homesquareSendEnquiry','homesquareLoadMyProperties','homesquareLoadEnquiries','homesquareSubmitForReview','homesquareDeleteDraft'])assert.ok(client.includes(method),method);
for(const table of ['profiles','properties','enquiries'])assert.ok(sql.includes('alter table public.'+table+' enable row level security'),table+' RLS');
assert.ok(!html.includes('function togglePublish('),'No insecure browser publish button');
assert.ok(html.includes('homesquareLoadMyProperties()'),'Dashboard should load server listings');
assert.ok(html.includes('homesquareLoadEnquiries(id)'),'Seller inbox should load server enquiries');
assert.ok(html.includes('name="amount"'),'Enquiries should support indicative offers');
assert.ok(html.includes('homesquareSignIn(event)'),'Account form must exist');
const features=fs.readFileSync('supabase/migrations/20261115010000_marketplace_features.sql','utf8');
for(const table of ['inspections','offers','messages','property_photos','service_requests']) {
 assert.ok(features.includes('create table public.'+table),'Missing '+table);
 assert.ok(features.includes('alter table public.'+table+' enable row level security'),'Missing RLS for '+table);
}
for(const method of ['homesquareRequestInspection','homesquareSubmitOffer','homesquareSendMessage','homesquareGetMessages','homesquareUploadPhoto','homesquareRequestService'])assert.ok(client.includes(method),'Missing '+method);
assert.ok(html.includes('requestInspection(id)'),'Inspection UI missing');
assert.ok(html.includes('submitOffer(id)'),'Offer UI missing');
assert.ok(html.includes('messageOwner(id)'),'Message UI missing');
assert.ok(features.includes("'property-photos',false"),'Photo bucket must remain private');
const decisions=fs.readFileSync('supabase/migrations/20261115020000_seller_decisions.sql','utf8');
for(const fn of ['seller_decide_inspection','seller_decide_offer'])assert.ok(decisions.includes('function public.'+fn),'Missing secured decision RPC '+fn);
assert.ok(html.includes('decideActivity(type,id,decision,propertyId)'),'Seller decisions UI missing');
assert.ok(client.includes('homesquareDecideInspection')&&client.includes('homesquareDecideOffer'),'Seller decision calls missing');
const moderation=fs.readFileSync('supabase/migrations/20261115030000_staff_moderation.sql','utf8');
for(const name of ['staff_review_listing','staff_review_ownership','enforce_property_status_transition'])assert.ok(moderation.includes('function public.'+name),'Missing '+name);
for(const table of ['staff_members','ownership_checks'])assert.ok(moderation.includes('alter table public.'+table+' enable row level security'),'Missing RLS '+table);
for(const name of ['homesquareIsStaff','homesquareStaffQueue','homesquareReviewOwnership','homesquareReviewListing','homesquareDeletePhoto'])assert.ok(client.includes(name),'Missing client '+name);
for(const name of ['showStaff()','showPhotos(id)','declareOwnership(id)'])assert.ok(html.includes(name),'Missing UI '+name);
const evidence=fs.readFileSync('supabase/migrations/20261115040000_ownership_evidence.sql','utf8');
assert.ok(evidence.includes("'ownership-evidence',false"),'Ownership evidence bucket must be private');
assert.ok(evidence.includes('protect_ownership_review'),'Ownership self-verification must be blocked');
assert.ok(evidence.includes('Supporting ownership evidence must be uploaded'),'Staff approval must require evidence');
for(const fn of ['homesquareUploadOwnershipEvidence','homesquareGetOwnershipEvidence'])assert.ok(client.includes(fn),'Missing '+fn);
for(const fn of ['uploadEvidence(id)','viewEvidence(id)'])assert.ok(html.includes(fn),'Missing '+fn);
const bookings=fs.readFileSync('supabase/migrations/20261115050000_service_booking.sql','utf8');
assert.ok(bookings.includes('function public.staff_update_service'),'Booking management RPC missing');
assert.ok(bookings.includes('Staff access required'),'Staff booking guard missing');
const feed=fs.readFileSync('supabase/migrations/20261115060000_activity_feed.sql','utf8');
assert.ok(feed.includes('security_invoker=true'),'Activity view must enforce table RLS');
for(const fn of ['homesquareLoadBuyerActivity','homesquareStaffServices','homesquareStaffUpdateService'])assert.ok(client.includes(fn),'Missing '+fn);
for(const fn of ['showBuyerDashboard()','staffServices()','showServiceBookings()','hydratePropertyPhotos('])assert.ok(html.includes(fn),'Missing '+fn);
console.log('PASS: JS parses, server integrations present, RLS declared, unsafe publish removed');

const test=require('node:test');

test('account switches clear private data and ignore late seller responses',async()=>{
 const elements=new Map();
 const pendingRefreshes=[];
 const window={homesquareBackendReady:true,addEventListener(){}};
 const document={getElementById(id){
  if(!elements.has(id))elements.set(id,{textContent:'',innerHTML:'',
   classList:{add(){},remove(){},contains(){return id!=='dashboardPage'}},
   cloneNode(){return {innerHTML:'',textContent:'',isConnected:true}},
   replaceWith(next){this.isConnected=false;elements.set(id,next)},
  });
  return elements.get(id);
 },body:{style:{}}};
 const context=vm.createContext({window,document,setTimeout:callback=>pendingRefreshes.push(callback)});
 new vm.Script(scripts(html)[0]).runInContext(context);
 window.homesquareAccountChanged('seller');

 let resolveListings;
 window.homesquareLoadMyProperties=()=>new Promise(resolve=>{resolveListings=resolve});
 const oldRequest=vm.runInContext('renderDashboard()',context);
 const dashboard=document.getElementById('dashboard');
 const gallery=document.getElementById('modalBody');
 gallery.innerHTML='Private gallery';
 vm.runInContext("sellerListingsCache=[{id:'seller-only'}];buyerActivityCache=[{id:'previous-activity'}]",context);

 window.homesquareAccountChanged(null);
 window.homesquareAccountChanged('buyer');
 assert.equal(dashboard.textContent,'');
 assert.equal(document.getElementById('modalBody').innerHTML,'');
 assert.equal(vm.runInContext('sellerListingsCache.length+buyerActivityCache.length',context),0);

 resolveListings([{status:'draft',address:'Seller-only address'}]);
 await oldRequest;
 assert.equal(dashboard.innerHTML,'');

 window.homesquareLoadMyProperties=async()=>[];
 pendingRefreshes.forEach(refresh=>refresh());
 await new Promise(resolve=>setImmediate(resolve));
 assert.match(dashboard.innerHTML,/No properties listed yet/);
});

test('listing writes retain marketing copy and valid price guides',async()=>{
 const writes=[];
 const result=fields=>{
  const query={eq:()=>query,select:()=>query,single:async()=>({data:fields})};
  writes.push(fields);
  return query;
 };
 const db={
  auth:{getUser:async()=>({data:{user:{id:'seller'}}}),onAuthStateChange(){}},
  from:()=>({insert:result,update:result}),
 };
 const window={HOMESQUARE_SUPABASE_URL:'https://example.invalid',HOMESQUARE_SUPABASE_PUBLISHABLE_KEY:'test',supabase:{createClient:()=>db}};
 new vm.Script(client).runInNewContext({window});
 const details={address:'QA Way',suburb:'Sydney',state:'NSW',property_type:'House',price:900000,beds:3,baths:2};
 await window.homesquareCreateDraft({...details,headline:'  Sydney home ',description:'Spacious kitchen',price_max:990000});
 assert.equal(writes[0].headline,'Sydney home');
 assert.equal(writes[0].description,'Spacious kitchen');
 assert.equal(writes[0].price_max,990000);
 await window.homesquareUpdateDraft('draft',{headline:'New headline',price:950000,price_max:''});
 assert.equal(writes[1].headline,'New headline');
 assert.equal(writes[1].price_max,null);
 await assert.rejects(window.homesquareCreateDraft({...details,price_max:1000001}),/at most/);
 await window.homesquareCreateDraft(details);
 assert.equal(writes[2].price_max,undefined);
});
