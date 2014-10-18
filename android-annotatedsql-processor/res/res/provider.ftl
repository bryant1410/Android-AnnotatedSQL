<#include "/provider_macroses.ftl">
/* AUTO-GENERATED FILE.  DO NOT MODIFY.
 *
 * This class was automatically generated by the AnnotatedSQL library.
  */
package ${pkgName};

<#list imports as import>
import ${import};     
</#list> 

import java.util.ArrayList;

import android.content.ContentProviderOperation;
import android.content.ContentProviderResult;
import android.content.OperationApplicationException;
import android.content.ContentProvider;
import android.content.ContentResolver;
import android.content.ContentValues;
import android.content.Context;
import android.content.UriMatcher;
import android.database.Cursor;
import android.database.DatabaseUtils.InsertHelper;
import android.database.sqlite.SQLiteDatabase;
import android.database.sqlite.SQLiteOpenHelper;
import android.database.sqlite.SQLiteQueryBuilder;
import android.net.Uri;
import android.net.Uri.Builder;
import android.text.TextUtils;
import android.util.Log;
import android.util.SparseArray;

public class ${className} extends ContentProvider{

    public static final String TAG = ${className}.class.getSimpleName();

    public static final String SUBTYPE_ITEM = ".item";
    public static final String SUBTYPE_DIR = ".dir";

    public static enum BulkInsertConflictMode {
        INSERT, REPLACE
    }

    public static final String AUTHORITY = "${authority}";

    @Deprecated
    public static final String FRAGMENT_NO_NOTIFY = UriBuilder.FRAGMENT_NO_NOTIFY;

    @Deprecated
    public static final String QUERY_LIMIT = UriBuilder.QUERY_LIMIT;

    @Deprecated
    public static final String QUERY_GROUP_BY = UriBuilder.QUERY_GROUP_BY;

    public static final Uri BASE_URI = Uri.parse("content://" + AUTHORITY);

    protected final static int MATCH_TYPE_ITEM = 0x0001;
    protected final static int MATCH_TYPE_DIR = 0x0002;
    protected final static int MATCH_TYPE_CUSTOM = 0x0003;
    protected final static int MATCH_TYPE_MASK = 0x000f;

    <#list entities as e>
    protected final static int MATCH_${getMatchName(e.path)} = ${e.codeHex};
    </#list>

    protected static final UriMatcher matcher = new UriMatcher(UriMatcher.NO_MATCH);
    protected static final SparseArray<String> customTypes = new SparseArray<String>();

    static {
        <#list entities as e>
        matcher.addURI(AUTHORITY, ${e.path}, MATCH_${getMatchName(e.path)});
        </#list>

        <#list entities as e>
            <#if e.hasCustomMimeType>
                <#if e.item>
        customTypes.put(MATCH_${getMatchName(e.path)}, "${e.customMimeType}" + SUBTYPE_ITEM);
                <#else>
        customTypes.put(MATCH_${getMatchName(e.path)}, "${e.customMimeType}" + SUBTYPE_DIR);
                </#if>
            </#if>
        </#list>
    }

    protected SQLiteOpenHelper dbHelper;
    protected ContentResolver contentResolver;

    protected BulkInsertConflictMode defaultBulkInsertConflictMode = BulkInsertConflictMode.${bulkInsertMode};
    protected int defaultInsertConflictMode = ${insertMode};

    @Override
    public boolean onCreate() {
        final Context context = getContext();
        <#if generateHelper>
        dbHelper = new AnnotationSql(context);
        <#else>
        dbHelper = new ${openHelperClass}(context);
        </#if>
        contentResolver = context.getContentResolver();
        return true;
    }
    
    @Override
    public String getType(Uri uri) {
        final String type;
        final int code = matcher.match(uri);
        switch (code & MATCH_TYPE_MASK) {
            case MATCH_TYPE_ITEM:
                type = ContentResolver.CURSOR_ITEM_BASE_TYPE + "/vnd." + AUTHORITY + SUBTYPE_ITEM;
                break;
            case MATCH_TYPE_DIR:
                type = ContentResolver.CURSOR_DIR_BASE_TYPE + "/vnd." + AUTHORITY + SUBTYPE_DIR;
                break;
            case MATCH_TYPE_CUSTOM:
                type = customTypes.get(code);
                break;
            default:
                throw new IllegalArgumentException("Unsupported uri " + uri);
            }
        return type;
    }

    @Override
    public Cursor query(Uri uri, String[] projection, String selection, String[] selectionArgs, String sortOrder) {
        final SQLiteQueryBuilder query = new SQLiteQueryBuilder();
        switch (matcher.match(uri)) {
            <#list entities as e>
            case MATCH_${getMatchName(e.path)}:{
            <#if e.rawQuery>
                Cursor c = dbHelper.getReadableDatabase().rawQuery(${schemaClassName}.${e.tableLink?upper_case}
                    + (TextUtils.isEmpty(selection) ? "" : " where " + selection) 
                    + (TextUtils.isEmpty(sortOrder) ? "" : " order by " + sortOrder)
                    , selectionArgs);
                c.setNotificationUri(getContext().getContentResolver(), uri);
                return c;  
            <#else>
                query.setTables(${e.tableLink});
                <#if e.item && e.where >
                selection = concatenateWhere(selection, "${e.selectColumn} = ? and ${e.queryWhere}");
                selectionArgs = appendSelectionArgs(selectionArgs, new String[]{uri.getLastPathSegment(), ${e.whereArgs}});
                <#elseif e.item>
                selection = concatenateWhere(selection, "${e.selectColumn} = ?");
                selectionArgs = appendSelectionArgs(selectionArgs, new String[]{uri.getLastPathSegment()});
                <#elseif e.where>
                selection = concatenateWhere(selection, "${e.queryWhere}");
                selectionArgs = appendSelectionArgs(selectionArgs, new String[]{${e.whereArgs}});
                </#if>
                break;
            </#if>
            }
            </#list> 
            default:
                throw new IllegalArgumentException("Unsupported uri " + uri);
        }
        Cursor c = query.query(dbHelper.getReadableDatabase(),
                projection, selection, selectionArgs,
                UriBuilder.getGroupBy(uri),
                null, sortOrder,
                UriBuilder.getLimit(uri));
        c.setNotificationUri(getContext().getContentResolver(), uri);
        
        return c;
    }

<#if supportTransaction>
    @Override
    public ContentProviderResult[] applyBatch(ArrayList<ContentProviderOperation> operations) throws OperationApplicationException {
        SQLiteDatabase sql = dbHelper.getWritableDatabase();
        sql.beginTransaction();
        ContentProviderResult[] res = null;
        try{
            res = super.applyBatch(operations);
            sql.setTransactionSuccessful();
        }finally{
            sql.endTransaction();
        }
        return res;
    }

    
    @Override
    public int bulkInsert(Uri uri, ContentValues[] valuesAr) {
        final String table;
        
        switch(matcher.match(uri)){
            <#list entities as e>
            <#if !e.item && !e.onlyQuery>
            case MATCH_${getMatchName(e.path)}:{
                table = ${e.tableLink};
                break;
            }
            </#if>
            </#list> 
            default:
                throw new IllegalArgumentException("Unsupported uri " + uri);
        }

        BulkInsertConflictMode conflict = UriBuilder.getBulkInsertConflictMode(uri, defaultBulkInsertConflictMode);
        SQLiteDatabase sql = dbHelper.getWritableDatabase();
        sql.beginTransaction();
        int count = 0;
        try {
            InsertHelper ih = new InsertHelper(sql, table);
            for (ContentValues values : valuesAr) {
            <#list entities as e>
                <@addInsertBeforeTrigger uri=e />
            </#list>
                long id;
                if(conflict == BulkInsertConflictMode.REPLACE) {
                    id = ih.replace(values);
                }else{
                    id = ih.insert(values);
                }
                if(id != -1) {
                    count++;
                }
            }
            ih.close();
            sql.setTransactionSuccessful();
            <#list entities as e>
                <@addInsertAfterTrigger uri=e />
            </#list>
        } finally {
            sql.endTransaction();
        }
        
        if (!UriBuilder.isIgnoreNotify(uri)) {
            notifyUri(contentResolver, uri);
        }
        return count;
    }

</#if>

    @Override
    @SuppressWarnings("unused")
    public Uri insert(Uri uri, ContentValues values) {
        final String table;
        
        switch(matcher.match(uri)){
            <#list entities as e>
            <#if !e.item && !e.onlyQuery>
            case MATCH_${getMatchName(e.path)}:{
                table = ${e.tableLink};
                break;
            }
            </#if>
            </#list> 
            default:
                throw new IllegalArgumentException("Unsupported uri " + uri);
        }
        <#list entities as e>
            <@addInsertBeforeTrigger uri=e />
        </#list>
        int conflictMode = UriBuilder.getInsertConflictMode(uri, defaultInsertConflictMode);
        long id = dbHelper.getWritableDatabase().insertWithOnConflict(table, null, values, conflictMode);
        <#list entities as e>
            <@addInsertAfterTrigger uri=e />
        </#list>
        if(!UriBuilder.isIgnoreNotify(uri)){
            notifyUri(contentResolver, uri);
        }
        return Uri.withAppendedPath(uri, String.valueOf(id));
    }

    @Override
    @SuppressWarnings("unused")
    public int update(Uri uri, ContentValues values, String selection, String[] selectionArgs) {
        final String table;
        String processedSelection = selection;
        
        switch(matcher.match(uri)){
            <#list entities as e>
            <#if !e.onlyQuery>
            case MATCH_${getMatchName(e.path)}:{
                table = ${e.tableLink};
                <#if e.item>
                processedSelection = composeIdSelection(selection, uri.getLastPathSegment(), "${e.selectColumn}");
                </#if>
                break;
            }
            </#if>
            </#list> 
            default:
                throw new IllegalArgumentException("Unsupported uri " + uri);
        }
        <#list entities as e>
            <@addUpdateBeforeTrigger uri=e />
        </#list>
        int count = dbHelper.getWritableDatabase().update(table, values, processedSelection, selectionArgs);
        <#list entities as e>
            <@addUpdateAfterTrigger uri=e />
        </#list>
        if(!UriBuilder.isIgnoreNotify(uri)){
            notifyUri(contentResolver, uri);
        }
        
        return count;
    }
    
    @Override
    @SuppressWarnings("unused")
    public int delete(Uri uri, String selection, String[] selectionArgs) {
        final String table;
        String processedSelection = selection;
        
        switch(matcher.match(uri)){
            <#list entities as e>
            <#if !e.onlyQuery>
            case MATCH_${getMatchName(e.path)}:{
                table = ${e.tableLink};
                <#if e.item>
                processedSelection = composeIdSelection(selection, uri.getLastPathSegment(), "${e.selectColumn}");
                </#if>
                break;
            }
            </#if>
            </#list> 
            default:
                throw new IllegalArgumentException("Unsupported uri " + uri);
        }
        <#list entities as e>
            <@addDeleteBeforeTrigger uri=e />
        </#list>
        int count = dbHelper.getWritableDatabase().delete(table, processedSelection, selectionArgs);
        <#list entities as e>
            <@addDeleteAfterTrigger uri=e />
        </#list>
        if(!UriBuilder.isIgnoreNotify(uri)){
            notifyUri(contentResolver, uri);
        }
        return count;
    }
    <#list entities as e>
        <#if e.triggered>
            <#list e.triggers as trigger>
                <#if trigger.insert && trigger.before>
            
    protected void on${trigger.methodName?cap_first}BeforeInserted(ContentValues values){
        
    }
                </#if>            
                <#if trigger.insert && trigger.after>
            
    protected void on${trigger.methodName?cap_first}AfterInserted(ContentValues values){
        
    }
                </#if>
            <#if trigger.delete && trigger.before>
            
    protected void on${trigger.methodName?cap_first}BeforeDeleted(Uri uri, String selection, String[] selectionArgs){
        
    }
            </#if>
            <#if trigger.delete && trigger.after>
            
    protected void on${trigger.methodName?cap_first}AfterDeleted(Uri uri, String selection, String[] selectionArgs){
        
    }
            </#if>
            <#if trigger.update && trigger.before>
            
    protected void on${trigger.methodName?cap_first}BeforeUpdated(Uri uri, ContentValues values, String selection, String[] selectionArg){
        
    }
            </#if>
            <#if trigger.update && trigger.after>
            
    protected void on${trigger.methodName?cap_first}AfterUpdated(Uri uri, ContentValues values, String selection, String[] selectionArg){
        
    }
            </#if>
            </#list>
        </#if>
    </#list>
    
    public static void notifyUri(ContentResolver cr, Uri uri){
        cr.notifyChange(uri, null);
        switch(matcher.match(uri)){
            <#list entities as e>
            <#if (e.hasAltNotify)>
            case MATCH_${getMatchName(e.path)}:{
                
                <#list e.altNotify as alt>
                    <#if e.item && alt.itemizedAltNotify>
                cr.notifyChange(getContentUri("${alt.value}", uri.getLastPathSegment()), null);
                    <#else>
                cr.notifyChange(getContentUri("${alt.value}"), null);
                    </#if>
                </#list>
                break;
            }
            </#if>
            </#list> 
        }
    }

    @Deprecated
    protected static boolean ignoreNotify(Uri uri){
        return UriBuilder.isIgnoreNotify(uri);
    }

    @Deprecated
    public static Uri getContentUri(String path){
        return getUriBuilder().append(path).build();
    }

    public static Uri contentUri(String path){
        return getUriBuilder().append(path).build();
    }

    @Deprecated
    public static Uri getContentUriGroupBy(String path, String groupBy){
        return getUriBuilder().append(path).groupBy(groupBy).build();
    }

    public static Uri contentUriGroupBy(String path, String groupBy){
        return getUriBuilder().append(path).groupBy(groupBy).build();
    }

    @Deprecated
    public static Uri getContentUri(String path, long id){
        return getUriBuilder().append(path).append(id).build();
    }

    public static Uri contentUri(String path, long id){
        return getUriBuilder().append(path).append(id).build();
    }

    @Deprecated
    public static Uri getContentUri(String path, String id){
        return getUriBuilder().append(path).append(id).build();
    }

    public static Uri contentUri(String path, String id){
        return getUriBuilder().append(path).append(id).build();
    }

    @Deprecated
    public static Uri getContentWithLimitUri(String path, int limit){
        return getUriBuilder().append(path).limit(limit).build();
    }

    public static Uri contentUriWithLimit(String path, int limit){
        return getUriBuilder().append(path).limit(limit).build();
    }

    @Deprecated
    public static Uri getNoNotifyContentUri(String path){
        return getUriBuilder().append(path).noNotify().build();
    }

    public static Uri contentUriNoNotify(String path){
        return getUriBuilder().append(path).noNotify().build();
    }

    public static Uri contentUriInsertNoNotify(String path, int conflicResolution){
        return getUriBuilder().append(path).noNotify().insertConflictMode(conflicResolution).build();
    }

    public static Uri contentUriInsert(String path, int conflicResolution){
        return getUriBuilder().append(path).insertConflictMode(conflicResolution).build();
    }

    public static Uri contentUriBulkInsertNoNotify(String path, BulkInsertConflictMode conflict){
        return getUriBuilder().append(path).noNotify().bulkInsertMode(conflict).build();
    }

    public static Uri contentUriBulkInsert(String path, BulkInsertConflictMode conflict){
        return getUriBuilder().append(path).bulkInsertMode(conflict).build();
    }

    @Deprecated
    public static Uri getNoNotifyContentUri(String path, long id){
        return getUriBuilder().append(path).append(id).noNotify().build();
    }

    public static UriBuilder getUriBuilder(){
        return new UriBuilder(BASE_URI);
    }

    public static class UriBuilder{

        public static final String FRAGMENT_NO_NOTIFY = "no-notify";
        public static final String QUERY_LIMIT = "limit";
        public static final String QUERY_GROUP_BY = "groupBy";
        public static final String QUERY_BULK_INSERT_CONFLICT_MODE = "biMode";
        public static final String QUERY_INSERT_CONFLICT_MODE = "icMode";

        private Uri.Builder uri;

        public UriBuilder(Uri uri){
            this.uri = uri.buildUpon();
        }

        public UriBuilder(String uri){
            this.uri = Uri.parse(uri).buildUpon();
        }

        public UriBuilder append(String path){
            if(TextUtils.isEmpty(path)){
                return this;
            }
            uri.appendPath(path);
            return this;
        }

        public UriBuilder append(long id){
            uri.appendPath(String.valueOf(id));
            return this;
        }

        public UriBuilder noNotify(){
            uri.fragment(FRAGMENT_NO_NOTIFY);
            return this;
        }

        public UriBuilder limit(int limit){
            uri.appendQueryParameter(QUERY_LIMIT, String.valueOf(limit));
            return this;
        }

        public UriBuilder insertConflictMode(int conflictMode){
            uri.appendQueryParameter(QUERY_INSERT_CONFLICT_MODE, String.valueOf(conflictMode));
            return this;
        }

        public UriBuilder bulkInsertMode(BulkInsertConflictMode conflict){
            uri.appendQueryParameter(QUERY_BULK_INSERT_CONFLICT_MODE, conflict.name());
            return this;
        }

        public UriBuilder groupBy(String groupBy){
            uri.appendQueryParameter(QUERY_GROUP_BY, groupBy);
            return this;
        }

        public Uri build(){
            return uri.build();
        }

        public Builder raw(){
            return uri;
        }

        public static boolean isIgnoreNotify(Uri uri) {
            return FRAGMENT_NO_NOTIFY.equals(uri.getFragment());
        }

        public static BulkInsertConflictMode getBulkInsertConflictMode(Uri uri, BulkInsertConflictMode defValue) {
            String mode = uri.getQueryParameter(QUERY_BULK_INSERT_CONFLICT_MODE);
            if(TextUtils.isEmpty(mode)){
                return defValue;
            }
            return BulkInsertConflictMode.valueOf(mode);
        }

        public static int getInsertConflictMode(Uri uri, int defValue) {
            String mode = uri.getQueryParameter(QUERY_INSERT_CONFLICT_MODE);
            if(TextUtils.isEmpty(mode)){
                return defValue;
            }
            try {
                return Integer.parseInt(mode);
            }catch (NumberFormatException e){
                Log.e(TAG, "getInsertConflict parse mode error", e);
                return defValue;
            }
        }

        public static String getLimit(Uri uri){
            return uri.getQueryParameter(QUERY_LIMIT);
        }

        public static String getGroupBy(Uri uri){
            return uri.getQueryParameter(QUERY_GROUP_BY);
        }
    }
    
    <#if generateHelper>   
    protected class AnnotationSql extends SQLiteOpenHelper {

        public AnnotationSql(Context context) {
            super(context, ${schemaClassName}.DB_NAME, null, ${schemaClassName}.DB_VERSION);
        }

        @Override
        public void onCreate(SQLiteDatabase db) {
            ${schemaClassName}.onCreate(db);
        }

        @Override
        public void onUpgrade(SQLiteDatabase db, int oldVersion, int newVersion) {
            ${schemaClassName}.onDrop(db);
            onCreate(db);
        }

    }
    </#if>

    public static String composeIdSelection(String originalSelection, String id, String idColumn) {
        StringBuffer sb = new StringBuffer();
        sb.append(idColumn).append('=').append(id);
        if (!TextUtils.isEmpty(originalSelection)) {
            sb.append(" AND (").append(originalSelection).append(')');
        }
        return sb.toString();
    }

    /**
     * Concatenates two SQL WHERE clauses, handling empty or null values.
     */
    public static String concatenateWhere(String a, String b) {
        if (TextUtils.isEmpty(a)) {
            return b;
        }
        if (TextUtils.isEmpty(b)) {
            return a;
        }

        return "(" + a + ") AND (" + b + ")";
    }

    /**
     * Appends one set of selection args to another. This is useful when adding a selection
     * argument to a user provided set.
     */
    public static String[] appendSelectionArgs(String[] originalValues, String[] newValues) {
        if (originalValues == null || originalValues.length == 0) {
            return newValues;
        }
        if (newValues == null || newValues.length == 0) {
            return originalValues;
        }
        String[] result = new String[originalValues.length + newValues.length ];
        System.arraycopy(originalValues, 0, result, 0, originalValues.length);
        System.arraycopy(newValues, 0, result, originalValues.length, newValues.length);
        return result;
    }

}