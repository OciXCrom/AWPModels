#include <amxmodx>
#include <amxmisc>
#include <cromchat>
#include <fakemeta>
#include <hamsandwich>
#include <nvault>

native crxranks_get_max_levels()
native crxranks_get_rank_by_level(level, buffer[], len)
native crxranks_get_user_level(id)
native crxranks_get_user_xp(id)

new const g_szNatives[][] =
{
	"crxranks_get_max_levels",
	"crxranks_get_rank_by_level",
	"crxranks_get_user_level",
	"crxranks_get_user_xp"
}

#if !defined m_pPlayer
	#define m_pPlayer 41
#endif

#if defined client_disconnected
	#define client_disconnect client_disconnected
#endif

#define PLUGIN_VERSION "2.1.4"
#define DEFAULT_V "models/v_awp.mdl"
#define DEFAULT_P "models/p_awp.mdl"
#define MAX_SOUND_LENGTH 128
#define MAX_AUTHID_LENGTH 35

#if !defined MAX_NAME_LENGTH
	#define MAX_NAME_LENGTH 32
#endif

#if !defined MAX_PLAYERS
	#define MAX_PLAYERS 32
#endif

enum _:AWP
{
	NAME[MAX_NAME_LENGTH],
	V_MODEL[MAX_SOUND_LENGTH],
	P_MODEL[MAX_SOUND_LENGTH],
	SELECT_SOUND[MAX_SOUND_LENGTH],
	FLAG,
	LEVEL,
	bool:SHOW_RANK,
	XP
}

new Array:g_aAWP,
	bool:g_bFirstTime[MAX_PLAYERS + 1],
	bool:g_bRankSystem,
	bool:g_bGetLevel,
	bool:g_bGetXP,
	g_eAWP[MAX_PLAYERS + 1][AWP],
	g_szAuth[MAX_PLAYERS + 1][MAX_AUTHID_LENGTH],
	g_iAWP[MAX_PLAYERS + 1],
	g_iCallback,
	g_pAtSpawn,
	g_pSaveChoice,
	g_iSaveChoice,
	g_iAWPNum,
	g_iVault

public plugin_init()
{
	register_plugin("AWP Models", PLUGIN_VERSION, "OciXCrom")
	register_cvar("CRXAWPModels", PLUGIN_VERSION, FCVAR_SERVER|FCVAR_SPONLY|FCVAR_UNLOGGED)
	
	if(!g_iAWPNum)
		set_fail_state("No AWPs found in the configuration file.")
	
	register_dictionary("AWPModels.txt")
	
	RegisterHam(Ham_Spawn, "player", "OnPlayerSpawn", 1)
	RegisterHam(Ham_Item_Deploy, "weapon_awp", "OnSelectAWP", 1)
	
	register_clcmd("say /awp", "ShowMenu")
	register_clcmd("say_team /awp", "ShowMenu")
	
	g_iCallback = menu_makecallback("CheckAWPAccess")
	g_pAtSpawn = register_cvar("am_open_at_spawn", "0")
	g_pSaveChoice = register_cvar("am_save_choice", "0")
}

public plugin_precache()
{
	if(LibraryExists("crxranks", LibType_Library))
		g_bRankSystem = true
		
	g_aAWP = ArrayCreate(AWP)
	ReadFile()
}

public plugin_cfg()
{
	g_iSaveChoice = get_pcvar_num(g_pSaveChoice)
	
	if(g_iSaveChoice)
		g_iVault = nvault_open("AWPModels")
}

public plugin_natives()
	set_native_filter("native_filter")
	
public native_filter(const szNative[], id, iTrap)
{
	if(!iTrap)
	{
		static i
		
		for(i = 0; i < sizeof(g_szNatives); i++)
		{
			if(equal(szNative, g_szNatives[i]))
				return PLUGIN_HANDLED
		}
	}
	
	return PLUGIN_CONTINUE
}
	
public plugin_end()
{
	ArrayDestroy(g_aAWP)
	
	if(g_iSaveChoice)
		nvault_close(g_iVault)
}

ReadFile()
{
	new szConfigsName[256], szFilename[256]
	get_configsdir(szConfigsName, charsmax(szConfigsName))
	formatex(szFilename, charsmax(szFilename), "%s/AWPModels.ini", szConfigsName)
	new iFilePointer = fopen(szFilename, "rt")
	
	if(iFilePointer)
	{
		new eAWP[AWP], szData[160], szKey[32], szValue[128], iMaxLevels
		
		if(g_bRankSystem)
			iMaxLevels = crxranks_get_max_levels()
		
		while(!feof(iFilePointer))
		{
			fgets(iFilePointer, szData, charsmax(szData))
			trim(szData)
			
			switch(szData[0])
			{
				case EOS, '#', ';': continue
				case '[':
				{
					if(szData[strlen(szData) - 1] == ']')
					{
						if(g_iAWPNum)
							PushAWP(eAWP)
							
						g_iAWPNum++
						replace(szData, charsmax(szData), "[", "")
						replace(szData, charsmax(szData), "]", "")
						copy(eAWP[NAME], charsmax(eAWP[NAME]), szData)
						
						eAWP[V_MODEL][0] = EOS
						eAWP[P_MODEL][0] = EOS
						eAWP[SELECT_SOUND][0] = EOS
						eAWP[FLAG] = ADMIN_ALL
						
						if(g_bRankSystem)
						{
							eAWP[LEVEL] = 0
							eAWP[SHOW_RANK] = false
							eAWP[XP] = 0
						}
					}
					else continue
				}
				default:
				{
					strtok(szData, szKey, charsmax(szKey), szValue, charsmax(szValue), '=')
					trim(szKey); trim(szValue)
					
					if(equal(szKey, "FLAG"))
						eAWP[FLAG] = read_flags(szValue)
					else if(equal(szKey, "LEVEL") && g_bRankSystem)
					{
						eAWP[LEVEL] = clamp(str_to_num(szValue), 0, iMaxLevels)
						
						if(!g_bGetLevel)
							g_bGetLevel = true
					}
					else if(equal(szKey, "SHOW_RANK") && g_bRankSystem)
						eAWP[SHOW_RANK] = _:clamp(str_to_num(szValue), false, true)
					else if(equal(szKey, "XP") && g_bRankSystem)
					{
						eAWP[XP] = _:clamp(str_to_num(szValue), 0)
						
						if(!g_bGetXP)
							g_bGetXP = true
					}
					else if(equal(szKey, "V_MODEL"))
					{
						if(!file_exists(szValue))
							log_amx("ERROR: model ^"%s^" not found!", szValue)
						else
						{
							precache_model(szValue)
							copy(eAWP[V_MODEL], charsmax(eAWP[V_MODEL]), szValue)
						}
					}
					else if(equal(szKey, "P_MODEL"))
					{
						if(!file_exists(szValue))
							log_amx("ERROR: model ^"%s^" not found!", szValue)
						else
						{
							precache_model(szValue)
							copy(eAWP[P_MODEL], charsmax(eAWP[P_MODEL]), szValue)
						}
					}
					else if(equal(szKey, "SELECT_SOUND"))
					{
						precache_sound(szValue)
						copy(eAWP[SELECT_SOUND], charsmax(eAWP[SELECT_SOUND]), szValue)
					}
				}
			}
		}
		
		if(g_iAWPNum)
			PushAWP(eAWP)
		
		fclose(iFilePointer)
	}
}

public client_connect(id)
{
	g_bFirstTime[id] = true
	ArrayGetArray(g_aAWP, 0, g_eAWP[id])
	g_iAWP[id] = 0
	
	if(g_iSaveChoice)
	{
		get_user_authid(id, g_szAuth[id], charsmax(g_szAuth[]))
		UseVault(id, false)
	}
}

public client_disconnect(id)
{
	if(g_iSaveChoice)
		UseVault(id, true)
}

public ShowMenu(id)
{
	static eAWP[AWP]
	new szTitle[128], szItem[128], iLevel, iXP
	formatex(szTitle, charsmax(szTitle), "%L", id, "AM_MENU_TITLE")

	if(g_bGetLevel)
		iLevel = crxranks_get_user_level(id)
	
	if(g_bGetXP)
		iXP = crxranks_get_user_xp(id)
		
	new iMenu = menu_create(szTitle, "MenuHandler")
	
	for(new iFlags = get_user_flags(id), i; i < g_iAWPNum; i++)
	{
		ArrayGetArray(g_aAWP, i, eAWP)
		copy(szItem, charsmax(szItem), eAWP[NAME])
		
		if(g_bRankSystem)
		{
			if(eAWP[LEVEL] && iLevel < eAWP[LEVEL])
			{
				if(eAWP[SHOW_RANK])
				{
					static szRank[32]
					crxranks_get_rank_by_level(eAWP[LEVEL], szRank, charsmax(szRank))
					format(szItem, charsmax(szItem), "%s %L", szItem, id, "AM_MENU_RANK", szRank)
				}
				else
					format(szItem, charsmax(szItem), "%s %L", szItem, id, "AM_MENU_LEVEL", eAWP[LEVEL])
			}
			
			if(eAWP[XP] && iXP < eAWP[XP])
				format(szItem, charsmax(szItem), "%s %L", szItem, id, "AM_MENU_XP", eAWP[XP])
		}
		
		if(eAWP[FLAG] != ADMIN_ALL && !(iFlags & eAWP[FLAG]))
			format(szItem, charsmax(szItem), "%s %L", szItem, id, "AM_MENU_VIP_ONLY")
			
		if(g_iAWP[id] == i)
			format(szItem, charsmax(szItem), "%s %L", szItem, id, "AM_MENU_SELECTED")
		
		menu_additem(iMenu, szItem, eAWP[NAME], eAWP[FLAG], g_iCallback)
	}
	
	if(menu_pages(iMenu) > 1)
	{
		formatex(szItem, charsmax(szItem), "%s%L", szTitle, id, "AM_MENU_TITLE_PAGE")
		menu_setprop(iMenu, MPROP_TITLE, szItem)
	}
		
	menu_display(id, iMenu)
	return PLUGIN_HANDLED
}

public MenuHandler(id, iMenu, iItem)
{
	if(iItem != MENU_EXIT)
	{
		g_iAWP[id] = iItem
		ArrayGetArray(g_aAWP, iItem, g_eAWP[id])
		
		if(is_user_alive(id) && get_user_weapon(id) == CSW_AWP)
			RefreshAWPModel(id)
		
		new szName[MAX_NAME_LENGTH], iUnused
		menu_item_getinfo(iMenu, iItem, iUnused, szName, charsmax(szName), .callback = iUnused)
		CC_SendMessage(id, "%L %L", id, "AM_CHAT_PREFIX", id, "AM_CHAT_SELECTED", szName)
		
		if(g_eAWP[id][SELECT_SOUND][0])
			engfunc(EngFunc_EmitSound, id, CHAN_AUTO, g_eAWP[id][SELECT_SOUND], 1.0, ATTN_NORM, 0, PITCH_NORM)
	}
	
	menu_destroy(iMenu)
	return PLUGIN_HANDLED
}	

public CheckAWPAccess(id, iMenu, iItem)
	return ((g_iAWP[id] == iItem) || !HasAWPAccess(id, iItem)) ? ITEM_DISABLED : ITEM_ENABLED

public OnPlayerSpawn(id)
{
	if(is_user_alive(id) && get_pcvar_num(g_pAtSpawn) && !g_iAWP[id] && g_bFirstTime[id])
	{
		g_bFirstTime[id] = false
		ShowMenu(id)
	}
}

public OnSelectAWP(iEnt)
{
	new id = get_pdata_cbase(iEnt, m_pPlayer, 4)
	
	if(is_user_connected(id))
		RefreshAWPModel(id)
}

RefreshAWPModel(const id)
{
	set_pev(id, pev_viewmodel2, g_eAWP[id][V_MODEL])
	set_pev(id, pev_weaponmodel2, g_eAWP[id][P_MODEL])
}

PushAWP(eAWP[AWP])
{
	if(!eAWP[V_MODEL][0])
		copy(eAWP[V_MODEL], charsmax(eAWP[V_MODEL]), DEFAULT_V)
		
	if(!eAWP[P_MODEL][0])
		copy(eAWP[P_MODEL], charsmax(eAWP[P_MODEL]), DEFAULT_P)
		
	ArrayPushArray(g_aAWP, eAWP)
}

bool:HasAWPAccess(const id, const iAWP)
{		
	static eAWP[AWP]
	ArrayGetArray(g_aAWP, iAWP, eAWP)
	
	if(g_bRankSystem)
	{
		if(eAWP[LEVEL] && crxranks_get_user_level(id) < eAWP[LEVEL])
			return false
			
		if(eAWP[XP] && crxranks_get_user_xp(id) < eAWP[XP])
			return false
	}
		
	if(eAWP[FLAG] != ADMIN_ALL && !(get_user_flags(id) & eAWP[FLAG]))
		return false
		
	return true
}

UseVault(const id, const bool:bSave)
{
	if(bSave)
	{
		static szData[4]
		num_to_str(g_iAWP[id], szData, charsmax(szData))
		nvault_set(g_iVault, g_szAuth[id], szData)
	}
	else
	{
		static iAWP
		iAWP = nvault_get(g_iVault, g_szAuth[id])
		
		if(iAWP > g_iAWPNum)
			iAWP = 0
		
		if(iAWP && HasAWPAccess(id, iAWP))
		{
			g_iAWP[id] = iAWP
			ArrayGetArray(g_aAWP, iAWP, g_eAWP[id])
			
			if(is_user_alive(id) && get_user_weapon(id) == CSW_AWP)
				RefreshAWPModel(id)
		}
	}
}	
