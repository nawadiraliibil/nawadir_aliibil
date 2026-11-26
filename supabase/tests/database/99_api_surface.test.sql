-- سطح الـAPI المتاح لأدوار العميل. كل إضافة أو حذف يحدّث هذا الملف والعقد
-- (contracts/api/rpc.yaml وread-surface.md) في المهمة نفسها.
begin;

create extension if not exists pgtap with schema extensions;

select plan(4);

select bag_eq(
  $$select p.proname::text from pg_proc p
    where p.pronamespace = 'public'::regnamespace
      and has_function_privilege('anon', p.oid, 'execute')$$,
  $$values ('get_published_settings'), ('get_current_policies'), ('storage_object_is_public'),
           ('search_listings'), ('resolve_listing_ref'), ('get_listing'), ('record_listing_view'),
           ('list_active_promotions'), ('record_promotion_event')$$,
  'دوال public المتاحة لـanon');

select bag_eq(
  $$select p.proname::text from pg_proc p
    where p.pronamespace = 'public'::regnamespace
      and has_function_privilege('authenticated', p.oid, 'execute')$$,
  $$values ('get_published_settings'), ('get_current_policies'),
           ('get_my_account'), ('update_my_profile'), ('set_my_avatar'), ('accept_policies'),
           ('has_staff_capability'), ('admin_whoami'), ('admin_grant_role'), ('admin_revoke_role'),
           ('storage_object_is_public'),
           ('create_listing_draft'), ('save_listing_draft'), ('add_listing_media'),
           ('remove_listing_media'), ('arrange_listing_media'), ('submit_listing'),
           ('start_listing_edit'), ('discard_listing_edit'), ('archive_listing'),
           ('delete_listing'), ('bump_listing'),
           ('admin_review_queue'), ('admin_list_listings'), ('admin_get_listing_review'),
           ('admin_approve_listing_version'), ('admin_reject_listing_version'),
           ('admin_hide_listing'), ('admin_unhide_listing'),
           ('admin_get_account'), ('admin_suspend_account'), ('admin_reactivate_account'),
           ('admin_upsert_region'), ('admin_upsert_city'), ('admin_upsert_breed'),
           ('admin_upsert_moderation_reason'), ('admin_set_lookup_active'), ('admin_reorder_lookup'),
           ('admin_get_settings'), ('admin_update_settings_draft'),
           ('admin_publish_settings'), ('admin_rollback_settings'),
           ('mark_notifications_read'),
           ('search_listings'), ('resolve_listing_ref'), ('get_listing'), ('record_listing_view'),
           ('add_favorite'), ('remove_favorite'),
           ('start_conversation'), ('send_message'), ('mark_conversation_read'), ('set_conversation_muted'),
           ('block_user'), ('unblock_user'), ('post_comment'), ('edit_comment'), ('delete_comment'),
           ('set_comments_closed'), ('admin_hide_comment'), ('admin_unhide_comment'),
           ('submit_report'), ('get_report_status'), ('admin_assign_report'), ('admin_set_report_status'),
           ('admin_close_report'), ('admin_get_report_evidence'),
           ('save_search'), ('delete_saved_search'), ('follow_seller'), ('unfollow_seller'),
           ('set_notification_preference'), ('register_device_token'), ('unregister_device_token'),
           ('get_rating_eligibility'), ('submit_rating'), ('edit_rating'), ('reply_to_rating'), ('appeal_rating'),
           ('admin_hide_rating'), ('admin_unhide_rating'), ('admin_decide_rating_appeal'),
           ('admin_stats'),
           ('list_active_promotions'), ('record_promotion_event'),
           ('admin_list_promotions'), ('admin_get_promotion'), ('admin_save_promotion'),
           ('admin_set_promotion_status'), ('admin_get_promotion_settings'), ('admin_update_promotion_settings')$$,
  'دوال public المتاحة لـauthenticated');

select bag_eq(
  $$select c.relname::text || ':' || priv
    from pg_class c
    cross join unnest(array['SELECT', 'INSERT', 'UPDATE', 'DELETE', 'TRUNCATE']) as priv
    where c.relnamespace = 'public'::regnamespace and c.relkind in ('r', 'v', 'm', 'p')
      and has_table_privilege('anon', c.oid, priv)$$,
  $$values ('regions:SELECT'), ('cities:SELECT'), ('breeds:SELECT'),
           ('public_profiles:SELECT'), ('public_listing_cards:SELECT'),
           ('public_listing_details:SELECT'), ('public_listing_media:SELECT'),
           ('public_comments:SELECT'), ('public_ratings:SELECT')$$,
  'صلاحيات anon على علاقات public');

select bag_eq(
  $$select c.relname::text || ':' || priv
    from pg_class c
    cross join unnest(array['SELECT', 'INSERT', 'UPDATE', 'DELETE', 'TRUNCATE']) as priv
    where c.relnamespace = 'public'::regnamespace and c.relkind in ('r', 'v', 'm', 'p')
      and has_table_privilege('authenticated', c.oid, priv)$$,
  $$values ('regions:SELECT'), ('cities:SELECT'), ('breeds:SELECT'),
           ('profiles:SELECT'), ('policy_consents:SELECT'),
           ('settings_versions:SELECT'), ('platform_settings:SELECT'),
           ('admin_roles:SELECT'), ('audit_log:SELECT'),
           ('moderation_reasons:SELECT'), ('listings:SELECT'), ('listing_versions:SELECT'),
           ('media:SELECT'), ('reviews:SELECT'), ('listing_bumps:SELECT'),
           ('public_profiles:SELECT'), ('public_listing_cards:SELECT'),
           ('public_listing_details:SELECT'), ('public_listing_media:SELECT'),
           ('my_listings:SELECT'), ('notifications:SELECT'), ('public_comments:SELECT'),
           ('favorites:SELECT'), ('my_favorites:SELECT'),
           ('conversations:SELECT'), ('messages:SELECT'), ('my_conversations:SELECT'),
           ('user_blocks:SELECT'), ('my_blocks:SELECT'),
           ('reports:SELECT'), ('report_evidence_access:SELECT'),
           ('saved_searches:SELECT'), ('follows:SELECT'), ('my_saved_searches:SELECT'), ('my_follows:SELECT'),
           ('notification_preferences:SELECT'), ('my_notification_preferences:SELECT'),
           ('seller_ratings:SELECT'), ('seller_rating_history:SELECT'), ('rating_replies:SELECT'),
           ('rating_appeals:SELECT'), ('public_ratings:SELECT'), ('my_received_ratings:SELECT')$$,
  'صلاحيات authenticated على علاقات public');

select * from finish();
rollback;
