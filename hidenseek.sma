/*-----------------------------------------------------------
 AMX Mod X script.

          | Author  : Hartmann
          | Plugin  : HideNSeek
          | Version : v1.0.beta
	  
 (!) Support : Github - https://github.com/Hartmannq
               AlliedModders - https://forums.alliedmods.net/member.php?u=255387
               Blog - http://hartmannq.blogspot.com/
               

 This program is free software; you can redistribute it and/or
 modify it under the terms of the GNU General Public License
 as published by the Free Software Foundation; either version 2
 of the License, or (at your option) any later version.

 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with this program; if not, write to the Free Software
 Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA. 
	      
------------------------------------------------------------*/
#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <fun>
#include <hamsandwich>
#include <fakemeta>
#include <cstrike>

new PLUGIN[] = "HideNSeek";
new AUTHOR[] = "Hartmann";
new VERSION[] = "1.0.beta";

#define fm_create_entity(%1)	engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, %1))

const iCountTime = 45;

new flashlight[33];
new color[33];
new g_iCountdownEntity;
new g_iCounter;
new g_SyncRestartTimer
new g_MaxPlayers;
new g_msgScreenFade;
new bool:hostageMade;
new bool:g_ttteam[ 33 ];
new bool:g_ctteam[ 33 ];
new bool:g_ct
new bool:g_rd
new g_Sync
new g_Sync2
new g_Sync3
new gmsgFlashlight

new g_color[][] = { 
	{100,0,0},{0,100,0},{0,0,100},{0,100,100},{100,0,100},{100,100,0},
	{100,0,60},{100,60,0},{0,100,60},{60,100,0},{0,60,100},{60,0,100},
	{100,50,50},{50,100,50},{50,50,100},{0,50,50},{50,0,50},{50,50,0}
}
new const g_objective_ents[][] = {
	"func_bomb_target",
	"info_bomb_target",
	"hostage_entity",
	"monster_scientist",
	"func_hostage_rescue",
	"info_hostage_rescue",
	"info_vip_start",
	"func_vip_safetyzone",
	"func_escapezone"
};

new cvar_mp_friendlyfire
new cvar_mp_freezetime
new cvar_mp_roundtime
new cvar_sv_gravity
new cvar_sv_restart
new cvar_humans_join_team
new cvar_mp_autoteambalance
new cvar_mp_limitteams
new cvar_mp_footsteps
new cvar_mp_maxrounds
new cvar_mp_timelimit
new CvarPrefix;
new Prefix[ 32 ];
new bool:g_bActivated[33];
new Float:g_SpawnVecs[3];
new Float:g_SpawnAngles[3];
new Float:g_SpawnVAngles[3];
new bool:g_LoadSuccessed = false

public plugin_precache() {
	register_forward(FM_KeyValue, "fwd_KeyValue", 1);
	readSpawns();
	new fog = fm_create_entity("env_fog");
	fm_set_kvd(fog, "density", "0.000650");
	
	new r = random_num(1, 128);
	new g = random_num(1, 128);
	new b = random_num(1, 128);
	
	new rouge[3], vert[3], bleu[3];
	num_to_str(r,rouge,2);
	num_to_str(g,vert,2);
	num_to_str(b,bleu,2);
	
	new test[12];
	formatex(test,11,"%s %s %s",rouge,vert,bleu);
	fm_set_kvd(fog,"rendercolor",test);
	server_cmd("sv_skyname space");
	precache_model("models/rpgrocket.mdl");
}
public plugin_init() {
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	register_cvar( "hidenseek_version", VERSION, FCVAR_SERVER | FCVAR_SPONLY);
	
	g_SyncRestartTimer = CreateHudSyncObj()
	g_Sync = CreateHudSyncObj()
	g_Sync2 = CreateHudSyncObj()
	g_Sync3 = CreateHudSyncObj()
	register_logevent("RestartTask", 2, "1=Round_Start") 
	g_iCountdownEntity = create_entity( "info_target" );
	entity_set_string( g_iCountdownEntity , EV_SZ_classname , "countdown_entity" );
	register_think( "countdown_entity" , "fw_CountdownEntThink" );
	g_MaxPlayers = get_maxplayers();
	g_msgScreenFade = get_user_msgid("ScreenFade");
	RegisterHam(Ham_Spawn, "player", "fwHamPlayerSpawnPost", 1)  
	register_event("SendAudio",	"endround",	"a", "2&%!MRAD_terwin", "2&%!MRAD_ctwin", "2&%!MRAD_rounddraw");
	register_event("TextMsg",	"gamestart",	"a", "2&#Game_C", "2&#Game_w");
	register_message(get_user_msgid("StatusIcon"), "Message_StatusIcon");
	register_forward(FM_PlayerPreThink,	"fwdPlayerPreThink");
	gmsgFlashlight	= get_user_msgid("Flashlight");
	register_event("Flashlight",	"event_flashlight", "b");
	register_clcmd("say /hns", "CmdActivate");
	set_task( 0.9, "count", 0, _, _, "b" );
	register_forward(FM_EmitSound,"fw_emitsound");
	register_event("DeathMsg", "eventDeath", "a"); 
	
	cvar_mp_friendlyfire = get_cvar_pointer("mp_friendlyfire")
	cvar_mp_freezetime = get_cvar_pointer("mp_freezetime")
	cvar_mp_roundtime = get_cvar_pointer("mp_roundtime")
	cvar_sv_gravity = get_cvar_pointer("sv_gravity")
	cvar_sv_restart = get_cvar_pointer("sv_restart")
	cvar_humans_join_team = get_cvar_pointer("humans_join_team")
	cvar_mp_autoteambalance = get_cvar_pointer("mp_autoteambalance")
	cvar_mp_limitteams = get_cvar_pointer("mp_limitteams")
	cvar_mp_footsteps = get_cvar_pointer("mp_footsteps")
	cvar_mp_maxrounds = get_cvar_pointer("mp_maxrounds")
	cvar_mp_timelimit = get_cvar_pointer("mp_timelimit")
	
	CvarPrefix = register_cvar( "hns_prefix", "HideNSeek" );
	get_pcvar_string( CvarPrefix, Prefix, charsmax( Prefix ) );
	register_clcmd("chooseteam", "handled");
	set_task(10.0, "checkplayer");
}
public plugin_cfg() { 
	set_pcvar_string(cvar_humans_join_team, "")
	set_pcvar_num(cvar_mp_freezetime, 0)
	set_pcvar_float(cvar_mp_roundtime, 3.77)
	set_pcvar_num(cvar_sv_gravity, 150);
	set_pcvar_num(cvar_mp_friendlyfire, 0)
	set_pcvar_num(cvar_mp_limitteams, 0 )
	set_cvar_string( "bot_join_team","")
	set_pcvar_string( cvar_mp_autoteambalance,"0")
	set_pcvar_num(cvar_mp_footsteps, 0);
	set_pcvar_num(cvar_mp_maxrounds, 6)
	set_pcvar_num(cvar_mp_timelimit, 0 )
	set_pcvar_num(cvar_sv_restart, 1) 
} 
stock readSpawns(){
	new Map[32], config[32],  MapFile[64];
	
	get_mapname(Map, 31);
	get_configsdir(config, 31 );
	format(MapFile, 63, "%s\hns\%s.spawns.cfg", config, Map);
	
	if (file_exists(MapFile)) 
	{
		new Data[124], len;
		new line = 0;
		new pos[12][8];
		new team[8]
		
		while((line = read_file(MapFile , line , Data , 123 , len) ) != 0 ) 
		{
			if (strlen(Data)<2 || Data[0] == '[')
				continue;
			
			parse(Data, team,7, pos[1], 7, pos[2], 7, pos[3], 7, pos[4], 7, pos[5], 7, pos[6], 7, pos[7], 7, pos[8], 7, pos[9], 7, pos[10], 7);
			
			// Origin
			g_SpawnVecs[0] = str_to_float(pos[1]);
			g_SpawnVecs[1] = str_to_float(pos[2]);
			g_SpawnVecs[2] = str_to_float(pos[3]);
			
			//Angles
			g_SpawnAngles[0] = str_to_float(pos[4]);
			g_SpawnAngles[1] = str_to_float(pos[5]);
			g_SpawnAngles[2] = str_to_float(pos[6]);
			
			//v-Angles
			g_SpawnVAngles[0] = str_to_float(pos[7]);
			g_SpawnVAngles[1] = str_to_float(pos[8]);
			g_SpawnVAngles[2] = str_to_float(pos[9]);
			
			
			if (equali(team,"T")){
				new ent_T = create_entity("info_player_deathmatch")
				
				entity_set_origin(ent_T, g_SpawnVecs);
				entity_set_int(ent_T, EV_INT_fixangle, 1);
				entity_set_vector(ent_T, EV_VEC_angles, g_SpawnAngles);
				entity_set_vector(ent_T, EV_VEC_v_angle, g_SpawnVAngles);
				entity_set_int(ent_T, EV_INT_fixangle, 1);
			}
			else if (equali(team,"CT")){
				new ent_CT = create_entity("info_player_start")
				
				entity_set_origin(ent_CT, g_SpawnVecs);
				entity_set_int(ent_CT, EV_INT_fixangle, 1);
				entity_set_vector(ent_CT, EV_VEC_angles, g_SpawnAngles);
				entity_set_vector(ent_CT, EV_VEC_v_angle, g_SpawnVAngles);
				entity_set_int(ent_CT, EV_INT_fixangle, 1);
			}
		}
		Spawns_Count()
		g_LoadSuccessed = true
		} else {
		log_amx("No spawn points file found (%s)", MapFile);
		g_LoadSuccessed = false
	}
	return 1;
}
stock Spawns_Count()
{
	new entity, g_SpawnT,g_SpawnCT 
	g_SpawnT = 0
	while ((entity = find_ent_by_class(entity, "info_player_deathmatch")))
		g_SpawnT++
	entity = 0
	g_SpawnCT = 0
	while ((entity = find_ent_by_class(entity, "info_player_start")))
		g_SpawnCT++
	new string[16]
	formatex(string,15,"T(%d) CT(%d)",g_SpawnT,g_SpawnCT)
	log_amx(string);
	register_cvar("hns_map_spawns",string,FCVAR_SERVER)
}
public restart(){
	set_pcvar_num(cvar_sv_restart, 1)
}
public checkplayer(){ 
	new iplayers[32], num;
	get_players(iplayers, num, "")
	set_lights("d");
	if(num >= 6){
		g_ct = true;
		remove_task(412566);
		set_pcvar_string(cvar_humans_join_team, "T")
		set_cvar_string( "bot_join_team","t")
		ClientPrintColor(0, "!g[%s] !gEnough players, let's go!",Prefix)
		set_task(10.0,"restart")
		}else{ 
		set_pcvar_string(cvar_humans_join_team, "")
		set_cvar_string( "bot_join_team","")
		g_ct = false;
		set_hudmessage(0, 255, 255, 0.01, 0.32, 2, 2.0, 3.0)
		ShowSyncHudMsg(0, g_Sync3, "Waiting for more players to join...")
	}
}
public RestartTask() {
	new iplayers[32], num;
	get_players(iplayers, num, "")
	
	if(num <= 5){
		set_task(20.0, "checkplayer", 412566, "", 0, "b");
		ClientPrintColor(0,"!g[%s] !gThere not enough players to round started.",Prefix)
	}
	else if(g_ct){
		set_hudmessage(255, 0, 0, -1.0, 0.20, 2, 2.0, 15.0)
		ShowSyncHudMsg( 0, g_Sync2, "Terrorists, you've got %d seconds to get hidden!" , iCountTime );
		g_rd = true
		g_iCounter = iCountTime;
		entity_set_float( g_iCountdownEntity , EV_FL_nextthink , get_gametime() + 1.0 );
		remove_task(412566);
	}
}
public fwHamPlayerSpawnPost(usr) {
	if (is_user_alive(usr)) {
		strip_user_weapons(usr);
		give_item(usr, "weapon_knife");
		set_view(usr, CAMERA_NONE)
		g_ttteam[usr] = false;
		if(g_ct && cs_get_user_team(usr) == CS_TEAM_CT){
			g_ctteam[usr] = true;
		}
	}
}  
public fw_CountdownEntThink( iEntity )
{
	if ( iEntity == g_iCountdownEntity ) 
	{
		set_hudmessage( 179, 0, 0, 0.3, 0.30, 0, 0.0, 1.0, 0.0, 0.0, -1)
		ShowSyncHudMsg( 0, g_SyncRestartTimer, "%d" , --g_iCounter );
		if ( g_iCounter ){
			entity_set_float( g_iCountdownEntity , EV_FL_nextthink , get_gametime() + 1.0 );
			new players[32];
			new pnum;
			new i;
			get_players(players,pnum,"e","TERRORIST");
			for (i=0; i<pnum; i++) {
				
				set_user_gravity(players[i], 0.25);
				set_user_maxspeed ( players[i], 0.0 )
				set_user_godmode(players[i], 1)
				g_ctteam[players[i]] = false;
				if( !cs_get_user_nvg(players[i]) ){
					cs_set_user_nvg(players[i], 1)
				}
				if ( g_iCounter == 5 )
					ClientPrintColor(players[i],"!g[%s] !gTerrorists, stop jumping or you'll crash on the ground!",Prefix)
			}
			get_players(players,pnum,"e","CT");
			for (i=0; i<pnum; i++) {
				set_user_gravity(players[i], 10.0);
				make_ScreenFade(players[i], 2.0, 135, 135, 135, 255);
				set_user_maxspeed ( players[i], 0.1 )
				set_user_godmode(players[i], 1)
				g_ctteam[players[i]] = true;
				cs_set_user_nvg(players[i], 0)
			}
			if ( g_iCounter <= 20 ){
				new temp[64]
				num_to_word(g_iCounter, temp, charsmax(temp))
				client_cmd(0,"speak ^"vox/%s^"", temp)
			}
			}else{
			new players[32];
			new pnum;
			new i;
			set_lights("a");
			get_players(players,pnum,"e","CT");
			for (i=0; i<pnum; i++) {
				set_user_gravity(players[i], 0.25);
				set_user_maxspeed ( players[i], 0.0 )
				give_item(players[i], "weapon_m4a1")
 				give_item(players[i], "weapon_ak47")
				give_item(players[i],"weapon_flashbang");
				give_item(players[i],"weapon_flashbang");
				cs_set_user_bpammo(players[i], CSW_M4A1,200)
				cs_set_user_bpammo(players[i], CSW_AK47,200)
				set_user_godmode(players[i], 1)
				cs_set_user_nvg(players[i], 0)
				ClientPrintColor(players[i],"!g[%s] !gCTs, go find the Terrorists and kill them!",Prefix)
				ClientPrintColor(players[i],"!g[%s] !gPress the F button to use the flashlight",Prefix)
			}
			get_players(players,pnum,"e","TERRORIST");
			for (i=0; i<pnum; i++) {
				set_user_gravity(players[i], 10.0);
				set_user_maxspeed ( players[i], 0.1 )
				set_user_godmode(players[i], 0)
				cs_set_user_nvg(players[i], 1)
				ClientPrintColor(players[i],"!g[%s] !gPress the N button to use the nightvision",Prefix)
				ClientPrintColor(players[i],"!g[%s] !gSay /hns for 3d camera.",Prefix)
			}	
		}
	} 
} 
public count(){
	if(g_ct){
		new players[32],numCT, numTT
		get_players(players, numCT, "ahe", "CT")
		get_players(players, numTT, "ahe", "TERRORIST")
		set_hudmessage(204, 102, 0, 0.80, 0.46, _, _, 1.0, _, _, 1)
		ShowSyncHudMsg(0, g_Sync, "Hide T:%d^nSeek CT:%d", numTT,numCT)
	}
}
public handled(usr) {
	if ( cs_get_user_team(usr) == CS_TEAM_UNASSIGNED )
		return PLUGIN_CONTINUE
	if(g_ct){
		return PLUGIN_HANDLED
	}
	return PLUGIN_CONTINUE
}
public CmdActivate(usr) {
	if ( cs_get_user_team(usr) == CS_TEAM_CT )
		return PLUGIN_HANDLED
	
	switch( g_bActivated[usr]){
		case true:
		{
			set_view(usr, CAMERA_NONE)
			g_bActivated[usr] = false;
		}
		case false:
		{
			set_view(usr, CAMERA_3RDPERSON)
			g_bActivated[usr] = true;
		}
	}
	return PLUGIN_CONTINUE
}

public fwd_KeyValue(entId, kvd_id) {
	if(!pev_valid(entId))
		return FMRES_IGNORED;
	
	static className[64];
	get_kvd(kvd_id, KV_ClassName, className, 63);
	for (new i = 0; i < sizeof g_objective_ents; ++i) {
		if(containi(className, g_objective_ents[i]) != -1)
			engfunc(EngFunc_RemoveEntity, entId);
	}
	if(!hostageMade) {
		hostageMade = true;
		new ent = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "hostage_entity"));
		engfunc(EngFunc_SetOrigin, ent, Float:{0.0,0.0,-55000.0});
		engfunc(EngFunc_SetSize, ent, Float:{-1.0,-1.0,-1.0}, Float:{1.0,1.0,1.0});
		dllfunc(DLLFunc_Spawn, ent);
	} 
	return FMRES_HANDLED;
}
public pfn_keyvalue(entid)
{  
	if (g_LoadSuccessed){
		new classname[32], key[32], value[32]
		copy_keyvalue(classname, 31, key, 31, value, 31)
		
		if (equal(classname, "info_player_deathmatch") || equal(classname, "info_player_start")){
			if (is_valid_ent(entid) && entity_get_int(entid,EV_INT_iuser1)!=1) 
				remove_entity(entid)
		}
	}
	return PLUGIN_CONTINUE
}
public client_putinserver(usr){
	random_num(0, sizeof( g_color ) - 1);
}
public gamestart() {
	if(g_ct){
		new cts[32], ctnum;
		set_lights("d");
		get_players(cts, ctnum, "e", "CT");
		for (new i=0; i<ctnum; i++) {
			cs_set_user_team(cts[i], CS_TEAM_T);
		}
		getplayer( )
	}
}
public endround(){
	if(g_ct){
		new players[32], num
		get_players(players, num, "")
		set_lights("d");
		if(g_rd){
			getplayer( )
			for( --num; num >= 0; num-- )
			{
				if(g_ctteam[players[num]]){
					cs_set_user_team(players[num], CS_TEAM_T);
					g_ctteam[players[num]] = false;
				} 
			} 
			}else{
			for( --num; num >= 0; num-- )
			{
				if(g_ctteam[players[num]]){
					cs_set_user_team(players[num], CS_TEAM_T);
					g_ctteam[players[num]] = false;
				} 
				if(g_ttteam[players[num]]){
					cs_set_user_team(players[num], CS_TEAM_CT);
					g_ttteam[players[num]] = false;
				} 
				
			} 
		}
	}
}
public eventDeath()
{
	if(g_ct){
		new players[32], total, iplayers[32], num;
		get_players(players, total, "ae", "TERRORIST" );
		get_players(iplayers, num, "")
		new retrieve = num/6;
		
		if(total <= retrieve){
			for (new i=0; i<total; i++) {
				g_ttteam[players[i]] = true;
				g_rd = false;
			}
		}
	}
}
public getplayer( ){
	if(g_ct){
		new players[32], total, iplayers[32], num;
		get_players(players, total, "ae", "TERRORIST" );
		get_players(iplayers, num, "")
		
		new retrieve = num/6;
		
		if( retrieve < total ){
			new selected[32], count, rand;
			do{
				rand = random(total);
				selected[count++] = players[rand];
				players[rand] = players[--total];
				cs_set_user_team(players[rand], CS_TEAM_CT);
			}
			while( count < retrieve );
		}
	}
}
public Message_StatusIcon(iMsgId, iMsgDest, usr)  {
	static szIcon[8];  
	get_msg_arg_string(2, szIcon, charsmax(szIcon));  
	if( equal(szIcon, "buyzone") ) 
	{  
		if( get_msg_arg_int(1) )  
		{
			set_pdata_int(usr, 235, get_pdata_int(usr, 235) & ~(1<<0)); 
			return PLUGIN_HANDLED;  
		}  
	}
	return PLUGIN_CONTINUE;  
}  
public event_flashlight(usr) {
	
	new CsTeams:iTeam = cs_get_user_team(usr)
	
	if(iTeam == CS_TEAM_T)
	{
		flashlight[usr] = 0;
	}
	else
	{
		if(flashlight[usr]) 
		{
			flashlight[usr] = 0;
			color[usr] = random_num(0, sizeof( g_color ) - 1);
		}
		else 
		{
			flashlight[usr] = 1;
		}
	}
	
	message_begin(MSG_ONE,gmsgFlashlight,_,usr);
	write_byte(flashlight[usr]);
	write_byte(100);
	message_end();
	set_pev(usr,pev_effects,pev(usr,pev_effects) & ~EF_DIMLIGHT);
}
public fwdPlayerPreThink(usr) 
{
	
	new a = color[usr];
	if(flashlight[usr]) 
	{
		new origin[3];
		get_user_origin(usr,origin,3);
		message_begin(MSG_BROADCAST,SVC_TEMPENTITY);
		write_byte(TE_DLIGHT);
		write_coord(origin[0]); 
		write_coord(origin[1]); 
		write_coord(origin[2]); 
		write_byte(20); 
		write_byte(g_color[a][0]); 
		write_byte(g_color[a][1]); 
		write_byte(g_color[a][2]); 
		write_byte(1);
		write_byte(60); 
		message_end();
	}
}
public fw_emitsound(entity,channel,const sample[],Float:volume,Float:attenuation,fFlags,pitch)
{

	if(!equali(sample,"weapons/flashbang-1.wav") && !equali(sample,"weapons/flashbang-2.wav"))
		return FMRES_IGNORED;
	
	flashbang_explode(entity);
	
	return FMRES_IGNORED;
}


public flashbang_explode(greindex)
{
	
	if(!pev_valid(greindex)) return;
	
	
	new Float:origin[3];
	pev(greindex,pev_origin,origin);
	
	
	message_begin(MSG_BROADCAST,SVC_TEMPENTITY);
	write_byte(27); 
	write_coord(floatround(origin[0])); 
	write_coord(floatround(origin[1])); 
	write_coord(floatround(origin[2])); 
	write_byte(50); 
	write_byte(255);
	write_byte(255); 
	write_byte(255); 
	write_byte(8); 
	write_byte(60); 
	message_end();
}
stock fm_set_kvd(entity, const key[], const value[], const classname[] = "") {
	if (classname[0])
		set_kvd(0, KV_ClassName, classname)
	else {
		new class[32]
		pev(entity, pev_classname, class, sizeof class - 1)
		set_kvd(0, KV_ClassName, class)
	}
	
	set_kvd(0, KV_KeyName, key)
	set_kvd(0, KV_Value, value)
	set_kvd(0, KV_fHandled, 0)
	
	return dllfunc(DLLFunc_KeyValue, entity, 0)
}
stock make_ScreenFade(usr, Float:fDuration, red, green, blue, alpha){
	new i = usr ? usr : get_player();
	if( !i )
	{
		return 0;
	}
	
	message_begin(usr ? MSG_ONE : MSG_ALL, g_msgScreenFade, {0, 0, 0}, usr);
	write_short(floatround(4096.0 * fDuration, floatround_round));
	write_short(floatround(4096.0 * fDuration, floatround_round));
	write_short(4096);
	write_byte(red);
	write_byte(green);
	write_byte(blue);
	write_byte(alpha);
	message_end();
	
	return 1;
}
stock get_player(){
	for( new usr = 1; usr <= g_MaxPlayers; usr++ )
	{
		if( is_user_connected(usr) )
		{
			return usr;
		}
	}
	
	return 0;
}
stock ClientPrintColor( usr, String[ ], any:... ){
	new szMsg[ 190 ]
	vformat( szMsg, charsmax( szMsg ), String, 3 )
	
	replace_all( szMsg, charsmax( szMsg ), "!n", "^1" )
	replace_all( szMsg, charsmax( szMsg ), "!t", "^3" )
	replace_all( szMsg, charsmax( szMsg ), "!g", "^4" )
	
	static msgSayText = 0
	static fake_user
	
	if( !msgSayText )
	{
		msgSayText = get_user_msgid( "SayText" )
		fake_user = get_maxplayers( ) + 1
	}
	
	message_begin( usr ? MSG_ONE_UNRELIABLE : MSG_BROADCAST, msgSayText, _, usr )
	write_byte( usr ? usr : fake_user )
	write_string( szMsg )
	message_end( )
}
