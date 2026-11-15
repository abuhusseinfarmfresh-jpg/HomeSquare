// Supabase-backed account and listings functions; activated when a publishable key is configured.
(function(){
const url=window.HOMESQUARE_SUPABASE_URL,key=window.HOMESQUARE_SUPABASE_PUBLISHABLE_KEY;
if(!url||!key){window.homesquareBackendReady=false;return}
const client=window.supabase?.createClient(url,key);
if(!client){console.error('Supabase client unavailable');return}
window.homesquareBackendReady=true;
window.homesquareDb=client;
const el=id=>document.getElementById(id);
function notify(message){el('accountMessage').textContent=message}
async function refresh(){
const {data:{user}}=await client.auth.getUser();
el('accountStatus').textContent=user?'Signed in: '+user.email:'Not signed in';
el('signOut').hidden=!user;
el('authForm').hidden=!!user;
}
window.homesquareSignIn=async function(e){
e.preventDefault();const f=new FormData(e.target),email=String(f.get('email')),password=String(f.get('password'));
const action=f.get('action');const result=action==='signup'?await client.auth.signUp({email,password}):await client.auth.signInWithPassword({email,password});
notify(result.error?result.error.message:action==='signup'?'Account created. Check your email if confirmation is required.':'Signed in successfully.');
await refresh();
};
window.homesquareSignOut=async function(){await client.auth.signOut();notify('Signed out.');await refresh()};
window.homesquareLoadProperties=async function(){
const {data,error}=await client.from('properties').select('id,address,suburb,state,property_type,price,beds,baths,status').eq('status','published').order('created_at',{ascending:false}).limit(100);
if(error)throw error;return data;
};
window.homesquareCreateDraft=async function(fields){
const {data:{user},error:authError}=await client.auth.getUser();if(authError||!user)throw new Error('Sign in first');
const {data,error}=await client.from('properties').insert({...fields,owner_id:user.id,status:'draft'}).select().single();
if(error)throw error;return data;
};
window.homesquareSendEnquiry=async function(property_id,kind,message,proposed_amount=null){
const {data:{user}}=await client.auth.getUser();if(!user)throw new Error('Sign in first');
const {data,error}=await client.from('enquiries').insert({property_id,buyer_id:user.id,kind,message,proposed_amount}).select().single();
if(error)throw error;return data;
};
window.homesquareLoadMyProperties=async function(){
 const {data:{user},error:authError}=await client.auth.getUser();
 if(authError||!user)throw new Error('Sign in to view your listings');
 const {data,error}=await client.from('properties').select('id,address,suburb,state,property_type,price,beds,baths,status,created_at').eq('owner_id',user.id).order('created_at',{ascending:false});
 if(error)throw error;return data;
};
window.homesquareDeleteDraft=async function(id){
 const {data,error}=await client.from('properties').delete().eq('id',id).eq('status','draft').select('id');
 if(error)throw error;if(!data?.length)throw new Error('Only your own drafts can be deleted');return true;
};
window.homesquareSubmitForReview=async function(id){
 const {data,error}=await client.from('properties').update({status:'pending_review'}).eq('id',id).eq('status','draft').select('id');
 if(error)throw error;if(!data?.length)throw new Error('Only your own drafts can be submitted');return true;
};
window.homesquareLoadEnquiries=async function(propertyId){
 const {data,error}=await client.from('enquiries').select('id,buyer_id,kind,message,proposed_amount,created_at').eq('property_id',propertyId).order('created_at',{ascending:false});
 if(error)throw error;return data;
};
window.homesquareLoadMyEnquiries=async function(){
 const {data:{user}}=await client.auth.getUser();if(!user)throw new Error('Sign in first');
 const {data,error}=await client.from('enquiries').select('id,property_id,kind,message,proposed_amount,created_at').eq('buyer_id',user.id).order('created_at',{ascending:false});
 if(error)throw error;return data;
};
async function currentUser(){const {data:{user},error}=await client.auth.getUser();if(error||!user)throw new Error('Sign in first');return user}
async function insertRow(table,record){const {data,error}=await client.from(table).insert(record).select().single();if(error)throw error;return data}
async function listRows(table,propertyId){const {data,error}=await client.from(table).select('*').eq('property_id',propertyId).order('created_at',{ascending:false});if(error)throw error;return data}
window.homesquareRequestInspection=async function(propertyId,date,message=''){const user=await currentUser();if(!date||new Date(date)<=new Date())throw new Error('Choose a future inspection time');return insertRow('inspections',{property_id:propertyId,buyer_id:user.id,requested_at:new Date(date).toISOString(),message})};
window.homesquareSubmitOffer=async function(propertyId,amount,message=''){const user=await currentUser();if(!Number.isFinite(Number(amount))||Number(amount)<=0)throw new Error('Enter a valid offer amount');return insertRow('offers',{property_id:propertyId,buyer_id:user.id,amount:Number(amount),message})};
window.homesquareSendMessage=async function(propertyId,buyerId,body){const user=await currentUser();return insertRow('messages',{property_id:propertyId,buyer_id:buyerId||user.id,sender_id:user.id,body})};
window.homesquareGetMessages=async function(propertyId,buyerId){const {data,error}=await client.from('messages').select('id,buyer_id,sender_id,body,created_at').eq('property_id',propertyId).eq('buyer_id',buyerId).order('created_at');if(error)throw error;return data};
window.homesquareLoadPropertyMessages=propertyId=>listRows('messages',propertyId);
window.homesquareDecideInspection=async function(id,decision){const {error}=await client.rpc('seller_decide_inspection',{p_id:id,p_decision:decision});if(error)throw error};
window.homesquareDecideOffer=async function(id,decision){const {error}=await client.rpc('seller_decide_offer',{p_id:id,p_decision:decision});if(error)throw error};
window.homesquareLoadInspections=propertyId=>listRows('inspections',propertyId);
window.homesquareLoadOffers=propertyId=>listRows('offers',propertyId);
window.homesquareLoadPhotos=async function(propertyId){const {data,error}=await client.from('property_photos').select('id,storage_path').eq('property_id',propertyId);if(error)throw error;return Promise.all(data.map(async p=>{const {data:signed,error:signError}=await client.storage.from('property-photos').createSignedUrl(p.storage_path,3600);if(signError)throw signError;return {...p,url:signed.signedUrl}}))};
window.homesquareUploadPhoto=async function(propertyId,file){
 await currentUser();
 if(!['image/jpeg','image/png','image/webp'].includes(file.type)||file.size>10485760)throw new Error('Use JPG, PNG or WebP under 10 MB');
 const ext=({'image/jpeg':'jpg','image/png':'png','image/webp':'webp'})[file.type],path=propertyId+'/'+crypto.randomUUID()+'.'+ext;
 const {error}=await client.storage.from('property-photos').upload(path,file,{contentType:file.type,upsert:false});if(error)throw error;
 try{return await insertRow('property_photos',{property_id:propertyId,storage_path:path})}
 catch(e){await client.storage.from('property-photos').remove([path]);throw e}
};
window.homesquareRequestService=async function(propertyId,service,details=''){const user=await currentUser();return insertRow('service_requests',{owner_id:user.id,property_id:propertyId||null,service,details})};
window.homesquareLoadServices=async function(){const user=await currentUser();const {data,error}=await client.from('service_requests').select('*').eq('owner_id',user.id).order('created_at',{ascending:false});if(error)throw error;return data};
client.auth.onAuthStateChange(()=>{refresh().catch(console.error)});
refresh().catch(console.error);
})();