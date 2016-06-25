package edu.berkeley.eecs.emission.cordova.serversync;

import android.content.Context;

import edu.berkeley.eecs.emission.R;
import edu.berkeley.eecs.emission.cordova.serversync.ServerSyncConfig;
import edu.berkeley.eecs.emission.cordova.usercache.UserCacheFactory;

/**
 * Created by shankari on 3/25/16.
 */

public class ConfigManager {
    private static ServerSyncConfig cachedConfig;

    public static ServerSyncConfig getConfig(Context context) {
        if (cachedConfig == null) {
            cachedConfig = readFromCache(context);
            if (cachedConfig == null) {
                // This is still NULL, which means that there is no document in the usercache.
                // Let us set it to the default settings
                // we don't want to save it to the database because then it will look like a user override
                cachedConfig = new ServerSyncConfig();
            }
        }
        return cachedConfig;
    }

    private static ServerSyncConfig readFromCache(Context context) {
        return UserCacheFactory.getUserCache(context)
                .getDocument(R.string.key_usercache_sync_config, ServerSyncConfig.class);
    }

    protected static void updateConfig(Context context, ServerSyncConfig newConfig) {
        UserCacheFactory.getUserCache(context)
                .putReadWriteDocument(R.string.key_usercache_sync_config, newConfig);
        cachedConfig = newConfig;
    }
}
