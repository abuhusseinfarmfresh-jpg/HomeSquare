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
 const {data,error}=await client.from('enquiries').select('id,kind,message,proposed_amount,created_at').eq('property_id',propertyId).order('created_at',{ascending:false});
 if(error)throw error;return data;
};
window.homesquareLoadMyEnquiries=async function(){
 const {data:{user}}=await client.auth.getUser();if(!user)throw new Error('Sign in first');
 const {data,error}=await client.from('enquiries').select('id,property_id,kind,message,proposed_amount,created_at').eq('buyer_id',user.id).order('created_at',{ascending:false});
 if(error)throw error;return data;
};
client.auth.onAuthStateChange(()=>{refresh().catch(console.error)});
refresh().catch(console.error);
})();