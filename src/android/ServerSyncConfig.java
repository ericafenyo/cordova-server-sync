package edu.berkeley.eecs.emission.cordova.serversync;

/**
 * Created by shankari on 10/20/15.
 */

public class ServerSyncConfig {
    private static final long DEFAULT_SYNC_INTERVAL = 60 * 60; // Changed to 10 secs to debug syncing issues on some android version

    public ServerSyncConfig() {
        this.sync_interval = DEFAULT_SYNC_INTERVAL;
    }

    public long getSyncInterval() {
        return this.sync_interval;
    }

    // We don't need any "set" fields because the entire document will be set as a whole
    // using the javascript interface
    private long sync_interval;
    private boolean ios_use_remote_push; // iOS only, unused
}
