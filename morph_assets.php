<?php

/**
* Morphs file and user asset types
* args: system-root, root-id, from-asset-type, to-asset-type, simulate
* usage: php morph_assets.php /path/to/matrix <root id> <from asset type code> <to asset type code>
*
* @author  Nic Hubbard <nic@zedsaid.com>
* @version $Version$ - 1.0
*/

error_reporting(E_ALL);
ini_set('memory_limit', '-1');
if ((php_sapi_name() != 'cli')) trigger_error("You can only run this script from the command line\n", E_USER_ERROR);

$SYSTEM_ROOT = (isset($_SERVER['argv'][1])) ? $_SERVER['argv'][1] : '';
if (empty($SYSTEM_ROOT)) {
	echo "ERROR: You need to supply the path to the System Root as the first argument\n";
	exit();
}

if (!is_dir($SYSTEM_ROOT) || !is_readable($SYSTEM_ROOT.'/core/include/init.inc')) {
	echo "ERROR: Path provided doesn't point to a Matrix installation's System Root. Please provide correct path and try again.\n";
	exit();
}
require_once $SYSTEM_ROOT.'/core/include/init.inc';
$am = $GLOBALS['SQ_SYSTEM']->am;

//ROOT ID
$ROOT_ID = (isset($_SERVER['argv'][2])) ? $_SERVER['argv'][2] : '';
if (empty($ROOT_ID)) {
	echo "ERROR: You need to provide the root ID as the second argument\n";
	exit();
}

//FROM_ASSET_TYPE
$FROM_ASSET_TYPE = (isset($_SERVER['argv'][3])) ? $_SERVER['argv'][3] : '';
if (empty($FROM_ASSET_TYPE)) {
	echo "ERROR: You need to enter the from_asset_type as the third argument\n";
	exit();
}
if (!$am->installed($FROM_ASSET_TYPE)) {
	echo "ERROR: $FROM_ASSET_TYPE is not a valid asset type\n";
	exit();
}

//TO_ASSET_TYPE
$TO_ASSET_TYPE = (isset($_SERVER['argv'][4])) ? $_SERVER['argv'][4] : '';
if (empty($TO_ASSET_TYPE)) {
	echo "ERROR: You need to enter the to_asset_type as the fourth argument\n";
	exit();
}
if (!$am->installed($TO_ASSET_TYPE)) {
	echo "ERROR: $TO_ASSET_TYPE is not a valid asset type\n";
	exit();
}

// SIMULATE
$SIMULATE = (isset($_SERVER['argv'][5])) ? $_SERVER['argv'][5] : '';
$SIMULATE_MODE = (!empty($SIMULATE) && $SIMULATE == '--simulate') ? TRUE : FALSE;

// Get the root user
$root_user = &$GLOBALS['SQ_SYSTEM']->am->getSystemAsset('root_user');

// log in as root
if (!$GLOBALS['SQ_SYSTEM']->setCurrentUser($root_user)) {
	echo "ERROR: Failed login as root user\n";
	exit();
}

// Morph the assets!
morphAssets($ROOT_ID, $FROM_ASSET_TYPE, $TO_ASSET_TYPE, $SIMULATE_MODE);

// Restore the current user
$GLOBALS['SQ_SYSTEM']->restoreCurrentUser();

/**
 * Morph Assets that allow it
 * 
 * @param $root					The root ID
 * @param $from_type			The asset type we are morphing from
 * @param $to_type				The asset type we are morphing to
 * @param $simulate				If we are in Simulate Mode
 * @return void
 */
function morphAssets($root, $from_type, $to_type, $simulate) {
	
	$am = $GLOBALS['SQ_SYSTEM']->am;
	
	//get the assetids
	$child_assetids = $am->getChildren($root, $from_type, TRUE, NULL, NULL, NULL, TRUE, 1, 1);
	
	//convert it to one dimension array
	$child_assetids = array_keys($child_assetids);
	
	$child_count = count($child_assetids);
	if ($child_count == 0) {
		echo "There were no matching assets found to morph.\n";
		return;	
	}
	
	//we are working, please wait
	if ($simulate) {
		echo "Simulate Morphing assets...\n";	
	} else {
		
		// Make sure the user wants to continue
		echo "There are $child_count $from_type assets to morph, are you sure you want to continue? Type 'yes' to continue:\n";
		$line = fgets(STDIN);
		if(trim($line) != 'yes'){
			echo "Aborting...\n";
			exit;
		}
		echo "Morphing assets...\n";	
	}
	
	// Convert each asset
	$able_to_morph = 0;
	foreach ($child_assetids as $child_assetid) {
		
		// Get the child asset
		$child_asset = $am->getAsset($child_assetid);
		
		// Morph to new asset type
		if (!$simulate) {
			$result = $child_asset->morph($to_type);
			if (!empty($result)) {
				$able_to_morph++;
				echo 'Morph Asset #'.$child_asset->id."\n";
			} else {
				echo "There was an error morphing $child_asset->id to $to_type\n";	
			}
		} else {
			$able_to_morph++;
			echo 'Simulate Morph Asset #'.$child_asset->id."\n";
		}//end
		
	}//end for each
	
	if ($simulate) {
		echo "Finished simulating morphing assets. $able_to_morph of $child_count $from_type assets can be morphed to $to_type assets.\n";	
	} else {
		echo "Finished morphing assets. $able_to_morph of $child_count $from_type assets were morphed to $to_type assets.\n";
	}
	
}//end

?>
