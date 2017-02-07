/**
 * Creates an adapter to post data to the SMAP server
 */
package edu.berkeley.eecs.emission.cordova.serversync;

import android.accounts.Account;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.AbstractThreadedSyncAdapter;
import android.content.ContentProviderClient;
import android.content.Context;
import android.content.Intent;
import android.content.SyncResult;
import android.os.Bundle;
import android.support.v4.app.NotificationCompat;
import android.support.v4.content.LocalBroadcastManager;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.io.IOException;
import java.util.Properties;

import edu.berkeley.eecs.emission.cordova.tracker.location.TripDiaryStateMachineReceiver;
import edu.berkeley.eecs.emission.cordova.tracker.sensors.BatteryUtils;
import edu.berkeley.eecs.emission.R;
import edu.berkeley.eecs.emission.cordova.jwtauth.GoogleAccountManagerAuth;
import edu.berkeley.eecs.emission.cordova.jwtauth.UserProfile;
import edu.berkeley.eecs.emission.cordova.tracker.wrapper.StatsEvent;
import edu.berkeley.eecs.emission.cordova.tracker.wrapper.Timer;
import edu.berkeley.eecs.emission.cordova.unifiedlogger.Log;
import edu.berkeley.eecs.emission.cordova.usercache.BuiltinUserCache;
import edu.berkeley.eecs.emission.cordova.usercache.UserCache;

/**
 * @author shankari
 *
 */
public class ServerSyncAdapter extends AbstractThreadedSyncAdapter {
	private String userName;
	private static final String TAG = "ServerSyncAdapter";

	Properties uuidMap;
	boolean syncSkip = false;
	Context cachedContext;
	// TODO: Figure out a principled way to do this
	private static int CONFIRM_TRIPS_ID = 99;
	
	public ServerSyncAdapter(Context context, boolean autoInitialize) {
		super(context, autoInitialize);
		
		System.out.println("Creating ConfirmTripsAdapter");
		// Dunno if it is OK to cache the context like this, but there are other
		// people doing it, so let's do it as well.
		// See https://nononsense-notes.googlecode.com/git-history/3716b44b527096066856133bfc8dfa09f9244db8/NoNonsenseNotes/src/com/nononsenseapps/notepad/sync/SyncAdapter.java
		// for an example
		cachedContext = context;
		// Our ContentProvider is a dummy so there is nothing else to do here
	}
	
	/* (non-Javadoc)
	 * @see android.content.AbstractThreadedSyncAdapter#onPerformSync(android.accounts.Account, android.os.Bundle, java.lang.String, android.content.ContentProviderClient, android.content.SyncResult)
	 */
	@Override
	public void onPerformSync(Account account, Bundle extras, String authority,
			ContentProviderClient provider, SyncResult syncResult) {
        android.util.Log.i("SYNC", "PERFORMING SYNC");
		Timer to = new Timer();

        long msTime = System.currentTimeMillis();
		String syncTs = String.valueOf(msTime);
		BuiltinUserCache biuc = BuiltinUserCache.getDatabase(cachedContext);
		biuc.putMessage(R.string.key_usercache_client_nav_event,
				new StatsEvent(cachedContext,R.string.sync_launched));
		
		/*
		 * Read the battery level when the app is being launched anyway.
		 */
		biuc.putSensorData(R.string.key_usercache_battery, BatteryUtils.getBatteryInfo(cachedContext));
				
		if (syncSkip == true) {
			System.err.println("Something is wrong and we have been asked to skip the sync, exiting immediately");
			return;
		}

		System.out.println("Can we use the extras bundle to transfer information? "+extras);
		// Get the list of uncategorized trips from the server
		// hardcoding the URL and the userID for now since we are still using fake data
		String userName = UserProfile.getInstance(cachedContext).getUserEmail();
		System.out.println("real user name = "+userName);

		if (userName == null || userName.trim().length() == 0) {
			System.out.println("we don't know who we are, so we can't get our data");
			performPeriodicActivity(cachedContext);
			return;
		}
		// First, get a token so that we can make the authorized calls to the server
		String userToken = GoogleAccountManagerAuth.getServerToken(cachedContext, userName);


		/*
		 * We send almost all pending trips to the server
		 */

		/*
		 * We are going to send over information for all the data in a single JSON object, to avoid overhead.
		 * So we take a quick check to see if the number of entries is zero.
		 */

		Log.i(cachedContext, TAG, "Starting sync with push");
		try {
			Timer t = new Timer();
			JSONArray entriesToPush = biuc.sync_phone_to_server();
			if (entriesToPush.length() == 0) {
				System.out.println("No data to send, returning early!");
			} else {
				CommunicationHelper.phone_to_server(cachedContext, userToken, entriesToPush);
				UserCache.TimeQuery tq = BuiltinUserCache.getTimeQuery(cachedContext, entriesToPush);
				biuc.clearEntries(tq);
				biuc.clearSupersededRWDocs(tq);
			}
			biuc.putMessage(R.string.key_usercache_client_time,
					new StatsEvent(cachedContext, R.string.push_duration, t.elapsedSecs()));
		} catch (JSONException e) {
			Log.e(cachedContext, TAG, "Error "+e+" while saving converting trips to JSON, skipping all of them");
			biuc.putMessage(R.string.key_usercache_client_error,
					new StatsEvent(cachedContext, R.string.push_duration));
		} catch (IOException e) {
			Log.e(cachedContext, TAG, "IO Error "+e+" while posting converted trips to JSON");
			biuc.putMessage(R.string.key_usercache_client_error,
					new StatsEvent(cachedContext, R.string.push_duration));
		}

		Log.i(cachedContext, TAG, "Push complete, now pulling");

        /*
         * Now, read all the information from the server. This is in a different try/catch block,
         * because we want to try it even if the push fails.
         */
		try {
			Timer t = new Timer();
			UserCache.TimeQuery tq = new UserCache.TimeQuery("write_ts", 0, System.currentTimeMillis()/1000);
			biuc.clearObsoleteDocs(tq);
			JSONArray entriesReceived = edu.berkeley.eecs.emission.cordova.serversync.CommunicationHelper.server_to_phone(
					cachedContext, userToken);
			biuc.sync_server_to_phone(entriesReceived);
			biuc.checkAfterPull();
			biuc.putMessage(R.string.key_usercache_client_time,
					new StatsEvent(cachedContext, R.string.pull_duration, t.elapsedSecs()));
		} catch (JSONException e) {
			Log.e(cachedContext, TAG, "Error "+e+" while saving converting trips to JSON, skipping all of them");
			biuc.putMessage(R.string.key_usercache_client_error,
					new StatsEvent(cachedContext, R.string.pull_duration));
		} catch (IOException e) {
			Log.e(cachedContext, TAG, "IO Error "+e+" while posting converted trips to JSON");
			biuc.putMessage(R.string.key_usercache_client_error,
					new StatsEvent(cachedContext, R.string.pull_duration));
		}

		performPeriodicActivity(cachedContext);
		// We are sending this only locally, so we don't care about the URI and so on.
        Intent localIntent = new Intent("edu.berkeley.eecs.emission.sync.NEW_DATA");
        Bundle b = new Bundle();
        b.putString( "userdata", "{}" );
        localIntent.putExtras(b);
        Log.i(cachedContext, TAG, "Finished sync, sending local broadcast");
        LocalBroadcastManager.getInstance(cachedContext).sendBroadcastSync(localIntent);
		biuc.putMessage(R.string.key_usercache_client_time,
				new StatsEvent(cachedContext, R.string.sync_duration, to.elapsedSecs()));
	}

	public static void performPeriodicActivity(Context cachedContext) {
		// TODO: Replace this by a broadcast notification to reduce dependency between the packages
		TripDiaryStateMachineReceiver.performPeriodicActivity(cachedContext);
	}

	/*
	 * Generates a notification for the user.
	 */
	
	public String getPath(String serviceName) {
		return "/"+userName+"/"+serviceName;
	}
}
