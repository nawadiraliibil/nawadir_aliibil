export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  graphql_public: {
    Tables: {
      [_ in never]: never
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      graphql: {
        Args: {
          extensions?: Json
          operationName?: string
          query?: string
          variables?: Json
        }
        Returns: Json
      }
    }
    Enums: {
      [_ in never]: never
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
  public: {
    Tables: {
      admin_roles: {
        Row: {
          capabilities: string[]
          granted_at: string
          granted_by: string | null
          is_active: boolean
          revoked_at: string | null
          revoked_by: string | null
          role: Database["public"]["Enums"]["staff_role"]
          updated_at: string
          user_id: string
        }
        Insert: {
          capabilities?: string[]
          granted_at?: string
          granted_by?: string | null
          is_active?: boolean
          revoked_at?: string | null
          revoked_by?: string | null
          role: Database["public"]["Enums"]["staff_role"]
          updated_at?: string
          user_id: string
        }
        Update: {
          capabilities?: string[]
          granted_at?: string
          granted_by?: string | null
          is_active?: boolean
          revoked_at?: string | null
          revoked_by?: string | null
          role?: Database["public"]["Enums"]["staff_role"]
          updated_at?: string
          user_id?: string
        }
        Relationships: []
      }
      audit_log: {
        Row: {
          action: string
          actor_id: string | null
          created_at: string
          details: Json
          id: number
          reason_code: string | null
          reason_text: string | null
          resource_id: string | null
          resource_type: string
        }
        Insert: {
          action: string
          actor_id?: string | null
          created_at?: string
          details?: Json
          id?: never
          reason_code?: string | null
          reason_text?: string | null
          resource_id?: string | null
          resource_type: string
        }
        Update: {
          action?: string
          actor_id?: string | null
          created_at?: string
          details?: Json
          id?: never
          reason_code?: string | null
          reason_text?: string | null
          resource_id?: string | null
          resource_type?: string
        }
        Relationships: []
      }
      breeds: {
        Row: {
          created_at: string
          id: number
          is_active: boolean
          name_ar: string
          requires_note: boolean
          sort_order: number
          updated_at: string
        }
        Insert: {
          created_at?: string
          id?: number
          is_active?: boolean
          name_ar: string
          requires_note?: boolean
          sort_order?: number
          updated_at?: string
        }
        Update: {
          created_at?: string
          id?: number
          is_active?: boolean
          name_ar?: string
          requires_note?: boolean
          sort_order?: number
          updated_at?: string
        }
        Relationships: []
      }
      cities: {
        Row: {
          created_at: string
          id: number
          is_active: boolean
          name_ar: string
          region_id: number
          sort_order: number
          updated_at: string
        }
        Insert: {
          created_at?: string
          id?: number
          is_active?: boolean
          name_ar: string
          region_id: number
          sort_order?: number
          updated_at?: string
        }
        Update: {
          created_at?: string
          id?: number
          is_active?: boolean
          name_ar?: string
          region_id?: number
          sort_order?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "cities_region_id_fkey"
            columns: ["region_id"]
            isOneToOne: false
            referencedRelation: "regions"
            referencedColumns: ["id"]
          },
        ]
      }
      comments: {
        Row: {
          author_id: string
          body: string
          created_at: string
          deleted_at: string | null
          edited_at: string | null
          hidden_at: string | null
          hidden_by: string | null
          hidden_reason_code: string | null
          hidden_reason_text: string | null
          id: string
          listing_id: string
          parent_id: string | null
          request_id: string
        }
        Insert: {
          author_id: string
          body: string
          created_at?: string
          deleted_at?: string | null
          edited_at?: string | null
          hidden_at?: string | null
          hidden_by?: string | null
          hidden_reason_code?: string | null
          hidden_reason_text?: string | null
          id?: string
          listing_id: string
          parent_id?: string | null
          request_id: string
        }
        Update: {
          author_id?: string
          body?: string
          created_at?: string
          deleted_at?: string | null
          edited_at?: string | null
          hidden_at?: string | null
          hidden_by?: string | null
          hidden_reason_code?: string | null
          hidden_reason_text?: string | null
          id?: string
          listing_id?: string
          parent_id?: string | null
          request_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "comments_author_id_fkey"
            columns: ["author_id"]
            isOneToOne: false
            referencedRelation: "my_conversations"
            referencedColumns: ["other_user_id"]
          },
          {
            foreignKeyName: "comments_author_id_fkey"
            columns: ["author_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "comments_author_id_fkey"
            columns: ["author_id"]
            isOneToOne: false
            referencedRelation: "public_profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "comments_hidden_reason_code_fkey"
            columns: ["hidden_reason_code"]
            isOneToOne: false
            referencedRelation: "moderation_reasons"
            referencedColumns: ["code"]
          },
          {
            foreignKeyName: "comments_listing_id_fkey"
            columns: ["listing_id"]
            isOneToOne: false
            referencedRelation: "listings"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "comments_listing_id_fkey"
            columns: ["listing_id"]
            isOneToOne: false
            referencedRelation: "my_listings"
            referencedColumns: ["listing_id"]
          },
          {
            foreignKeyName: "comments_listing_id_fkey"
            columns: ["listing_id"]
            isOneToOne: false
            referencedRelation: "public_listing_cards"
            referencedColumns: ["listing_id"]
          },
          {
            foreignKeyName: "comments_listing_id_fkey"
            columns: ["listing_id"]
            isOneToOne: false
            referencedRelation: "public_listing_details"
            referencedColumns: ["listing_id"]
          },
          {
            foreignKeyName: "comments_listing_id_fkey"
            columns: ["listing_id"]
            isOneToOne: false
            referencedRelation: "public_listing_media"
            referencedColumns: ["listing_id"]
          },
          {
            foreignKeyName: "comments_parent_id_fkey"
            columns: ["parent_id"]
            isOneToOne: false
            referencedRelation: "comments"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "comments_parent_id_fkey"
            columns: ["parent_id"]
            isOneToOne: false
            referencedRelation: "public_comments"
            referencedColumns: ["comment_id"]
          },
        ]
      }
      conversations: {
        Row: {
          buyer_id: string
          buyer_muted: boolean
          buyer_read_at: string | null
          created_at: string
          id: string
          last_message_at: string | null
          listing_id: string
          seller_id: string
          seller_muted: boolean
          seller_read_at: string | null
        }
        Insert: {
          buyer_id: string
          buyer_muted?: boolean
          buyer_read_at?: string | null
          created_at?: string
          id?: string
          last_message_at?: string | null
          listing_id: string
          seller_id: string
          seller_muted?: boolean
          seller_read_at?: string | null
        }
        Update: {
          buyer_id?: string
          buyer_muted?: boolean
          buyer_read_at?: string | null
          created_at?: string
          id?: string
          last_message_at?: string | null
          listing_id?: string
          seller_id?: string
          seller_muted?: boolean
          seller_read_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "conversations_buyer_id_fkey"
            columns: ["buyer_id"]
            isOneToOne: false
            referencedRelation: "my_conversations"
            referencedColumns: ["other_user_id"]
          },
          {
            foreignKeyName: "conversations_buyer_id_fkey"
            columns: ["buyer_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "conversations_buyer_id_fkey"
            columns: ["buyer_id"]
            isOneToOne: false
            referencedRelation: "public_profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "conversations_listing_id_fkey"
            columns: ["listing_id"]
            isOneToOne: false
            referencedRelation: "listings"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "conversations_listing_id_fkey"
            columns: ["listing_id"]
            isOneToOne: false
            referencedRelation: "my_listings"
            referencedColumns: ["listing_id"]
          },
          {
            foreignKeyName: "conversations_listing_id_fkey"
            columns: ["listing_id"]
            isOneToOne: false
            referencedRelation: "public_listing_cards"
            referencedColumns: ["listing_id"]
          },
          {
            foreignKeyName: "conversations_listing_id_fkey"
            columns: ["listing_id"]
            isOneToOne: false
            referencedRelation: "public_listing_details"
            referencedColumns: ["listing_id"]
          },
          {
            foreignKeyName: "conversations_listing_id_fkey"
            columns: ["listing_id"]
            isOneToOne: false
            referencedRelation: "public_listing_media"
            referencedColumns: ["listing_id"]
          },
          {
            foreignKeyName: "conversations_seller_id_fkey"
            columns: ["seller_id"]
            isOneToOne: false
            referencedRelation: "my_conversations"
            referencedColumns: ["other_user_id"]
          },
          {
            foreignKeyName: "conversations_seller_id_fkey"
            columns: ["seller_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "conversations_seller_id_fkey"
            columns: ["seller_id"]
            isOneToOne: false
            referencedRelation: "public_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      device_tokens: {
        Row: {
          created_at: string
          disabled_at: string | null
          id: string
          last_seen_at: string
          platform: string
          token: string
          user_id: string
        }
        Insert: {
          created_at?: string
          disabled_at?: string | null
          id?: string
          last_seen_at?: string
          platform: string
          token: string
          user_id: string
        }
        Update: {
          created_at?: string
          disabled_at?: string | null
          id?: string
          last_seen_at?: string
          platform?: string
          token?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "device_tokens_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "my_conversations"
            referencedColumns: ["other_user_id"]
          },
          {
            foreignKeyName: "device_tokens_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "device_tokens_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "public_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      favorites: {
        Row: {
          created_at: string
          listing_id: string
          user_id: string
        }
        Insert: {
          created_at?: string
          listing_id: string
          user_id: string
        }
        Update: {
          created_at?: string
          listing_id?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "favorites_listing_id_fkey"
            columns: ["listing_id"]
            isOneToOne: false
            referencedRelation: "listings"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "favorites_listing_id_fkey"
            columns: ["listing_id"]
            isOneToOne: false
            referencedRelation: "my_listings"
            referencedColumns: ["listing_id"]
          },
          {
            foreignKeyName: "favorites_listing_id_fkey"
            columns: ["listing_id"]
            isOneToOne: false
            referencedRelation: "public_listing_cards"
            referencedColumns: ["listing_id"]
          },
          {
            foreignKeyName: "favorites_listing_id_fkey"
            columns: ["listing_id"]
            isOneToOne: false
            referencedRelation: "public_listing_details"
            referencedColumns: ["listing_id"]
          },
          {
            foreignKeyName: "favorites_listing_id_fkey"
            columns: ["listing_id"]
            isOneToOne: false
            referencedRelation: "public_listing_media"
            referencedColumns: ["listing_id"]
          },
          {
            foreignKeyName: "favorites_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "my_conversations"
            referencedColumns: ["other_user_id"]
          },
          {
            foreignKeyName: "favorites_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "favorites_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "public_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      follows: {
        Row: {
          created_at: string
          follower_id: string
          seller_id: string
        }
        Insert: {
          created_at?: string
          follower_id: string
          seller_id: string
        }
        Update: {
          created_at?: string
          follower_id?: string
          seller_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "follows_follower_id_fkey"
            columns: ["follower_id"]
            isOneToOne: false
            referencedRelation: "my_conversations"
            referencedColumns: ["other_user_id"]
          },
          {
            foreignKeyName: "follows_follower_id_fkey"
            columns: ["follower_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "follows_follower_id_fkey"
            columns: ["follower_id"]
            isOneToOne: false
            referencedRelation: "public_profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "follows_seller_id_fkey"
            columns: ["seller_id"]
            isOneToOne: false
            referencedRelation: "my_conversations"
            referencedColumns: ["other_user_id"]
          },
          {
            foreignKeyName: "follows_seller_id_fkey"
            columns: ["seller_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "follows_seller_id_fkey"
            columns: ["seller_id"]
            isOneToOne: false
            referencedRelation: "public_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      listing_bumps: {
        Row: {
          actor_id: string
          bumped_at: string
          id: number
          listing_id: string
        }
        Insert: {
          actor_id: string
          bumped_at?: string
          id?: never
          listing_id: string
        }
        Update: {
          actor_id?: string
          bumped_at?: string
          id?: never
          listing_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "listing_bumps_listing_id_fkey"
            columns: ["listing_id"]
            isOneToOne: false
            referencedRelation: "listings"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "listing_bumps_listing_id_fkey"
            columns: ["listing_id"]
            isOneToOne: false
            referencedRelation: "my_listings"
            referencedColumns: ["listing_id"]
          },
          {
            foreignKeyName: "listing_bumps_listing_id_fkey"
            columns: ["listing_id"]
            isOneToOne: false
            referencedRelation: "public_listing_cards"
            referencedColumns: ["listing_id"]
          },
          {
            foreignKeyName: "listing_bumps_listing_id_fkey"
            columns: ["listing_id"]
            isOneToOne: false
            referencedRelation: "public_listing_details"
            referencedColumns: ["listing_id"]
          },
          {
            foreignKeyName: "listing_bumps_listing_id_fkey"
            columns: ["listing_id"]
            isOneToOne: false
            referencedRelation: "public_listing_media"
            referencedColumns: ["listing_id"]
          },
        ]
      }
      listing_stats: {
        Row: {
          favorite_count: number
          listing_id: string
          view_count: number
        }
        Insert: {
          favorite_count?: number
          listing_id: string
          view_count?: number
        }
        Update: {
          favorite_count?: number
          listing_id?: string
          view_count?: number
        }
        Relationships: [
          {
            foreignKeyName: "listing_stats_listing_id_fkey"
            columns: ["listing_id"]
            isOneToOne: true
            referencedRelation: "listings"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "listing_stats_listing_id_fkey"
            columns: ["listing_id"]
            isOneToOne: true
            referencedRelation: "my_listings"
            referencedColumns: ["listing_id"]
          },
          {
            foreignKeyName: "listing_stats_listing_id_fkey"
            columns: ["listing_id"]
            isOneToOne: true
            referencedRelation: "public_listing_cards"
            referencedColumns: ["listing_id"]
          },
          {
            foreignKeyName: "listing_stats_listing_id_fkey"
            columns: ["listing_id"]
            isOneToOne: true
            referencedRelation: "public_listing_details"
            referencedColumns: ["listing_id"]
          },
          {
            foreignKeyName: "listing_stats_listing_id_fkey"
            columns: ["listing_id"]
            isOneToOne: true
            referencedRelation: "public_listing_media"
            referencedColumns: ["listing_id"]
          },
        ]
      }
      listing_versions: {
        Row: {
          age_months: number | null
          auction_city_id: number | null
          auction_lat: number | null
          auction_lng: number | null
          auction_region_id: number | null
          auction_starts_at: string | null
          auction_venue: string | null
          breed_id: number | null
          breed_note: string | null
          city_id: number | null
          color: string | null
          contact_call_enabled: boolean
          contact_consent_at: string | null
          contact_phone: string | null
          contact_whatsapp_enabled: boolean
          contact_whatsapp_phone: string | null
          content_hash: string | null
          created_at: string
          decided_at: string | null
          description: string | null
          health_notes: string | null
          id: string
          listing_id: string
          offer_type: Database["public"]["Enums"]["offer_type"] | null
          owner_declaration_at: string | null
          price: number | null
          region_id: number | null
          settings_version: number | null
          sex: Database["public"]["Enums"]["animal_sex"] | null
          status: Database["public"]["Enums"]["listing_version_status"]
          submit_request_id: string | null
          submitted_at: string | null
          title: string | null
          updated_at: string
          version_no: number
        }
        Insert: {
          age_months?: number | null
          auction_city_id?: number | null
          auction_lat?: number | null
          auction_lng?: number | null
          auction_region_id?: number | null
          auction_starts_at?: string | null
          auction_venue?: string | null
          breed_id?: number | null
          breed_note?: string | null
          city_id?: number | null
          color?: string | null
          contact_call_enabled?: boolean
          contact_consent_at?: string | null
          contact_phone?: string | null
          contact_whatsapp_enabled?: boolean
          contact_whatsapp_phone?: string | null
          content_hash?: string | null
          created_at?: string
          decided_at?: string | null
          description?: string | null
          health_notes?: string | null
          id?: string
          listing_id: string
          offer_type?: Database["public"]["Enums"]["offer_type"] | null
          owner_declaration_at?: string | null
          price?: number | null
          region_id?: number | null
          settings_version?: number | null
          sex?: Database["public"]["Enums"]["animal_sex"] | null
          status?: Database["public"]["Enums"]["listing_version_status"]
          submit_request_id?: string | null
          submitted_at?: string | null
          title?: string | null
          updated_at?: string
          version_no: number
        }
        Update: {
          age_months?: number | null
          auction_city_id?: number | null
          auction_lat?: number | null
          auction_lng?: number | null
          auction_region_id?: number | null
          auction_starts_at?: string | null
          auction_venue?: string | null
          breed_id?: number | null
          breed_note?: string | null
          city_id?: number | null
          color?: string | null
          contact_call_enabled?: boolean
          contact_consent_at?: string | null
          contact_phone?: string | null
          contact_whatsapp_enabled?: boolean
          contact_whatsapp_phone?: string | null
          content_hash?: string | null
          created_at?: string
          decided_at?: string | null
          description?: string | null
          health_notes?: string | null
          id?: string
          listing_id?: string
          offer_type?: Database["public"]["Enums"]["offer_type"] | null
          owner_declaration_at?: string | null
          price?: number | null
          region_id?: number | null
          settings_version?: number | null
          sex?: Database["public"]["Enums"]["animal_sex"] | null
          status?: Database["public"]["Enums"]["listing_version_status"]
          submit_request_id?: string | null
          submitted_at?: string | null
          title?: string | null
          updated_at?: string
          version_no?: number
        }
        Relationships: [
          {
            foreignKeyName: "listing_versions_auction_city_id_auction_region_id_fkey"
            columns: ["auction_city_id", "auction_region_id"]
            isOneToOne: false
            referencedRelation: "cities"
            referencedColumns: ["id", "region_id"]
          },
          {
            foreignKeyName: "listing_versions_auction_region_id_fkey"
            columns: ["auction_region_id"]
            isOneToOne: false
            referencedRelation: "regions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "listing_versions_breed_id_fkey"
            columns: ["breed_id"]
            isOneToOne: false
            referencedRelation: "breeds"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "listing_versions_city_id_region_id_fkey"
            columns: ["city_id", "region_id"]
            isOneToOne: false
            referencedRelation: "cities"
            referencedColumns: ["id", "region_id"]
          },
          {
            foreignKeyName: "listing_versions_listing_id_fkey"
            columns: ["listing_id"]
            isOneToOne: false
            referencedRelation: "listings"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "listing_versions_listing_id_fkey"
            columns: ["listing_id"]
            isOneToOne: false
            referencedRelation: "my_listings"
            referencedColumns: ["listing_id"]
          },
          {
            foreignKeyName: "listing_versions_listing_id_fkey"
            columns: ["listing_id"]
            isOneToOne: false
            referencedRelation: "public_listing_cards"
            referencedColumns: ["listing_id"]
          },
          {
            foreignKeyName: "listing_versions_listing_id_fkey"
            columns: ["listing_id"]
            isOneToOne: false
            referencedRelation: "public_listing_details"
            referencedColumns: ["listing_id"]
          },
          {
            foreignKeyName: "listing_versions_listing_id_fkey"
            columns: ["listing_id"]
            isOneToOne: false
            referencedRelation: "public_listing_media"
            referencedColumns: ["listing_id"]
          },
          {
            foreignKeyName: "listing_versions_region_id_fkey"
            columns: ["region_id"]
            isOneToOne: false
            referencedRelation: "regions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "listing_versions_settings_version_fkey"
            columns: ["settings_version"]
            isOneToOne: false
            referencedRelation: "settings_versions"
            referencedColumns: ["version"]
          },
        ]
      }
      listing_view_log: {
        Row: {
          listing_id: string
          viewer: string
        }
        Insert: {
          listing_id: string
          viewer: string
        }
        Update: {
          listing_id?: string
          viewer?: string
        }
        Relationships: [
          {
            foreignKeyName: "listing_view_log_listing_id_fkey"
            columns: ["listing_id"]
            isOneToOne: false
            referencedRelation: "listings"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "listing_view_log_listing_id_fkey"
            columns: ["listing_id"]
            isOneToOne: false
            referencedRelation: "my_listings"
            referencedColumns: ["listing_id"]
          },
          {
            foreignKeyName: "listing_view_log_listing_id_fkey"
            columns: ["listing_id"]
            isOneToOne: false
            referencedRelation: "public_listing_cards"
            referencedColumns: ["listing_id"]
          },
          {
            foreignKeyName: "listing_view_log_listing_id_fkey"
            columns: ["listing_id"]
            isOneToOne: false
            referencedRelation: "public_listing_details"
            referencedColumns: ["listing_id"]
          },
          {
            foreignKeyName: "listing_view_log_listing_id_fkey"
            columns: ["listing_id"]
            isOneToOne: false
            referencedRelation: "public_listing_media"
            referencedColumns: ["listing_id"]
          },
        ]
      }
      listings: {
        Row: {
          comments_closed: boolean
          create_request_id: string
          created_at: string
          current_version_id: string | null
          deleted_at: string | null
          first_published_at: string | null
          first_submitted_at: string | null
          id: string
          last_bumped_at: string | null
          last_published_at: string | null
          owner_id: string
          public_ref: string
          published_version_at: string | null
          published_version_id: string | null
          status: Database["public"]["Enums"]["listing_status"]
          status_changed_at: string
          updated_at: string
          visibility_updated_at: string | null
        }
        Insert: {
          comments_closed?: boolean
          create_request_id: string
          created_at?: string
          current_version_id?: string | null
          deleted_at?: string | null
          first_published_at?: string | null
          first_submitted_at?: string | null
          id?: string
          last_bumped_at?: string | null
          last_published_at?: string | null
          owner_id: string
          public_ref?: string
          published_version_at?: string | null
          published_version_id?: string | null
          status?: Database["public"]["Enums"]["listing_status"]
          status_changed_at?: string
          updated_at?: string
          visibility_updated_at?: string | null
        }
        Update: {
          comments_closed?: boolean
          create_request_id?: string
          created_at?: string
          current_version_id?: string | null
          deleted_at?: string | null
          first_published_at?: string | null
          first_submitted_at?: string | null
          id?: string
          last_bumped_at?: string | null
          last_published_at?: string | null
          owner_id?: string
          public_ref?: string
          published_version_at?: string | null
          published_version_id?: string | null
          status?: Database["public"]["Enums"]["listing_status"]
          status_changed_at?: string
          updated_at?: string
          visibility_updated_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "listings_current_version_fk"
            columns: ["id", "current_version_id"]
            isOneToOne: false
            referencedRelation: "listing_versions"
            referencedColumns: ["listing_id", "id"]
          },
          {
            foreignKeyName: "listings_owner_id_fkey"
            columns: ["owner_id"]
            isOneToOne: false
            referencedRelation: "my_conversations"
            referencedColumns: ["other_user_id"]
          },
          {
            foreignKeyName: "listings_owner_id_fkey"
            columns: ["owner_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "listings_owner_id_fkey"
            columns: ["owner_id"]
            isOneToOne: false
            referencedRelation: "public_profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "listings_published_version_fk"
            columns: ["id", "published_version_id"]
            isOneToOne: false
            referencedRelation: "listing_versions"
            referencedColumns: ["listing_id", "id"]
          },
        ]
      }
      media: {
        Row: {
          bucket: string
          created_at: string
          duration_seconds: number | null
          failure_reason: string | null
          height: number | null
          id: string
          is_cover: boolean
          kind: Database["public"]["Enums"]["media_kind"]
          listing_id: string
          mime_type: string | null
          object_path: string
          owner_id: string
          size_bytes: number | null
          sort_order: number
          status: Database["public"]["Enums"]["media_status"]
          updated_at: string
          version_id: string
          width: number | null
        }
        Insert: {
          bucket: string
          created_at?: string
          duration_seconds?: number | null
          failure_reason?: string | null
          height?: number | null
          id?: string
          is_cover?: boolean
          kind: Database["public"]["Enums"]["media_kind"]
          listing_id: string
          mime_type?: string | null
          object_path: string
          owner_id: string
          size_bytes?: number | null
          sort_order?: number
          status?: Database["public"]["Enums"]["media_status"]
          updated_at?: string
          version_id: string
          width?: number | null
        }
        Update: {
          bucket?: string
          created_at?: string
          duration_seconds?: number | null
          failure_reason?: string | null
          height?: number | null
          id?: string
          is_cover?: boolean
          kind?: Database["public"]["Enums"]["media_kind"]
          listing_id?: string
          mime_type?: string | null
          object_path?: string
          owner_id?: string
          size_bytes?: number | null
          sort_order?: number
          status?: Database["public"]["Enums"]["media_status"]
          updated_at?: string
          version_id?: string
          width?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "media_listing_id_version_id_fkey"
            columns: ["listing_id", "version_id"]
            isOneToOne: false
            referencedRelation: "listing_versions"
            referencedColumns: ["listing_id", "id"]
          },
          {
            foreignKeyName: "media_owner_id_fkey"
            columns: ["owner_id"]
            isOneToOne: false
            referencedRelation: "my_conversations"
            referencedColumns: ["other_user_id"]
          },
          {
            foreignKeyName: "media_owner_id_fkey"
            columns: ["owner_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "media_owner_id_fkey"
            columns: ["owner_id"]
            isOneToOne: false
            referencedRelation: "public_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      messages: {
        Row: {
          body: string
          conversation_id: string
          created_at: string
          id: string
          request_id: string
          sender_id: string
        }
        Insert: {
          body: string
          conversation_id: string
          created_at?: string
          id?: string
          request_id: string
          sender_id: string
        }
        Update: {
          body?: string
          conversation_id?: string
          created_at?: string
          id?: string
          request_id?: string
          sender_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "messages_conversation_id_fkey"
            columns: ["conversation_id"]
            isOneToOne: false
            referencedRelation: "conversations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "messages_conversation_id_fkey"
            columns: ["conversation_id"]
            isOneToOne: false
            referencedRelation: "my_conversations"
            referencedColumns: ["conversation_id"]
          },
          {
            foreignKeyName: "messages_sender_id_fkey"
            columns: ["sender_id"]
            isOneToOne: false
            referencedRelation: "my_conversations"
            referencedColumns: ["other_user_id"]
          },
          {
            foreignKeyName: "messages_sender_id_fkey"
            columns: ["sender_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "messages_sender_id_fkey"
            columns: ["sender_id"]
            isOneToOne: false
            referencedRelation: "public_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      moderation_reasons: {
        Row: {
          applies_to: string[]
          code: string
          created_at: string
          is_active: boolean
          label_ar: string
          requires_note: boolean
          sort_order: number
          updated_at: string
        }
        Insert: {
          applies_to: string[]
          code: string
          created_at?: string
          is_active?: boolean
          label_ar: string
          requires_note?: boolean
          sort_order?: number
          updated_at?: string
        }
        Update: {
          applies_to?: string[]
          code?: string
          created_at?: string
          is_active?: boolean
          label_ar?: string
          requires_note?: boolean
          sort_order?: number
          updated_at?: string
        }
        Relationships: []
      }
      notification_outbox: {
        Row: {
          attempts: number
          created_at: string
          id: number
          last_error: string | null
          next_attempt_at: string
          notification_id: string
          status: string
          updated_at: string
        }
        Insert: {
          attempts?: number
          created_at?: string
          id?: never
          last_error?: string | null
          next_attempt_at?: string
          notification_id: string
          status?: string
          updated_at?: string
        }
        Update: {
          attempts?: number
          created_at?: string
          id?: never
          last_error?: string | null
          next_attempt_at?: string
          notification_id?: string
          status?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "notification_outbox_notification_id_fkey"
            columns: ["notification_id"]
            isOneToOne: true
            referencedRelation: "notifications"
            referencedColumns: ["id"]
          },
        ]
      }
      notification_preferences: {
        Row: {
          category: Database["public"]["Enums"]["notification_category"]
          push_enabled: boolean
          updated_at: string
          user_id: string
        }
        Insert: {
          category: Database["public"]["Enums"]["notification_category"]
          push_enabled?: boolean
          updated_at?: string
          user_id: string
        }
        Update: {
          category?: Database["public"]["Enums"]["notification_category"]
          push_enabled?: boolean
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "notification_preferences_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "my_conversations"
            referencedColumns: ["other_user_id"]
          },
          {
            foreignKeyName: "notification_preferences_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "notification_preferences_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "public_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      notifications: {
        Row: {
          category: Database["public"]["Enums"]["notification_category"]
          created_at: string
          dedupe_key: string
          event: string
          id: string
          payload: Json
          read_at: string | null
          recipient_id: string
          resource_id: string
          resource_type: string
        }
        Insert: {
          category: Database["public"]["Enums"]["notification_category"]
          created_at?: string
          dedupe_key: string
          event: string
          id?: string
          payload?: Json
          read_at?: string | null
          recipient_id: string
          resource_id: string
          resource_type: string
        }
        Update: {
          category?: Database["public"]["Enums"]["notification_category"]
          created_at?: string
          dedupe_key?: string
          event?: string
          id?: string
          payload?: Json
          read_at?: string | null
          recipient_id?: string
          resource_id?: string
          resource_type?: string
        }
        Relationships: [
          {
            foreignKeyName: "notifications_recipient_id_fkey"
            columns: ["recipient_id"]
            isOneToOne: false
            referencedRelation: "my_conversations"
            referencedColumns: ["other_user_id"]
          },
          {
            foreignKeyName: "notifications_recipient_id_fkey"
            columns: ["recipient_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "notifications_recipient_id_fkey"
            columns: ["recipient_id"]
            isOneToOne: false
            referencedRelation: "public_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      platform_settings: {
        Row: {
          draft: Json | null
          draft_updated_at: string | null
          draft_updated_by: string | null
          id: boolean
          published_version: number
          updated_at: string
        }
        Insert: {
          draft?: Json | null
          draft_updated_at?: string | null
          draft_updated_by?: string | null
          id?: boolean
          published_version: number
          updated_at?: string
        }
        Update: {
          draft?: Json | null
          draft_updated_at?: string | null
          draft_updated_by?: string | null
          id?: boolean
          published_version?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "platform_settings_published_version_fkey"
            columns: ["published_version"]
            isOneToOne: false
            referencedRelation: "settings_versions"
            referencedColumns: ["version"]
          },
        ]
      }
      policy_consents: {
        Row: {
          accepted_at: string
          document_id: number
          user_id: string
        }
        Insert: {
          accepted_at?: string
          document_id: number
          user_id: string
        }
        Update: {
          accepted_at?: string
          document_id?: number
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "policy_consents_document_id_fkey"
            columns: ["document_id"]
            isOneToOne: false
            referencedRelation: "policy_documents"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "policy_consents_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "my_conversations"
            referencedColumns: ["other_user_id"]
          },
          {
            foreignKeyName: "policy_consents_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "policy_consents_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "public_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      policy_documents: {
        Row: {
          body: string
          id: number
          is_placeholder: boolean
          kind: Database["public"]["Enums"]["policy_kind"]
          published_at: string
          title: string
          version: number
        }
        Insert: {
          body: string
          id?: number
          is_placeholder?: boolean
          kind: Database["public"]["Enums"]["policy_kind"]
          published_at?: string
          title: string
          version: number
        }
        Update: {
          body?: string
          id?: number
          is_placeholder?: boolean
          kind?: Database["public"]["Enums"]["policy_kind"]
          published_at?: string
          title?: string
          version?: number
        }
        Relationships: []
      }
      profiles: {
        Row: {
          avatar_path: string | null
          created_at: string
          display_name: string | null
          id: string
          region_id: number | null
          status: Database["public"]["Enums"]["account_status"]
          status_changed_at: string | null
          suspension_reason_code: string | null
          suspension_reason_text: string | null
          updated_at: string
        }
        Insert: {
          avatar_path?: string | null
          created_at?: string
          display_name?: string | null
          id: string
          region_id?: number | null
          status?: Database["public"]["Enums"]["account_status"]
          status_changed_at?: string | null
          suspension_reason_code?: string | null
          suspension_reason_text?: string | null
          updated_at?: string
        }
        Update: {
          avatar_path?: string | null
          created_at?: string
          display_name?: string | null
          id?: string
          region_id?: number | null
          status?: Database["public"]["Enums"]["account_status"]
          status_changed_at?: string | null
          suspension_reason_code?: string | null
          suspension_reason_text?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "profiles_region_id_fkey"
            columns: ["region_id"]
            isOneToOne: false
            referencedRelation: "regions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "profiles_suspension_reason_code_fkey"
            columns: ["suspension_reason_code"]
            isOneToOne: false
            referencedRelation: "moderation_reasons"
            referencedColumns: ["code"]
          },
        ]
      }
      promotion_event_log: {
        Row: {
          kind: string
          promotion_id: string
          viewer: string
          window_start: string
        }
        Insert: {
          kind: string
          promotion_id: string
          viewer: string
          window_start: string
        }
        Update: {
          kind?: string
          promotion_id?: string
          viewer?: string
          window_start?: string
        }
        Relationships: [
          {
            foreignKeyName: "promotion_event_log_promotion_id_fkey"
            columns: ["promotion_id"]
            isOneToOne: false
            referencedRelation: "promotions"
            referencedColumns: ["id"]
          },
        ]
      }
      promotion_settings: {
        Row: {
          enabled: boolean
          feed_interval: number
          id: boolean
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          enabled?: boolean
          feed_interval?: number
          id?: boolean
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          enabled?: boolean
          feed_interval?: number
          id?: boolean
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: []
      }
      promotions: {
        Row: {
          action_type: Database["public"]["Enums"]["promotion_action"]
          action_value: string | null
          advertiser_name: string
          body: string | null
          click_count: number
          created_at: string
          created_by: string | null
          ends_at: string | null
          id: string
          image_path: string
          impression_count: number
          placements: string[]
          priority: number
          region_ids: number[] | null
          starts_at: string
          status: Database["public"]["Enums"]["promotion_status"]
          title: string
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          action_type: Database["public"]["Enums"]["promotion_action"]
          action_value?: string | null
          advertiser_name: string
          body?: string | null
          click_count?: number
          created_at?: string
          created_by?: string | null
          ends_at?: string | null
          id?: string
          image_path: string
          impression_count?: number
          placements: string[]
          priority?: number
          region_ids?: number[] | null
          starts_at: string
          status?: Database["public"]["Enums"]["promotion_status"]
          title: string
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          action_type?: Database["public"]["Enums"]["promotion_action"]
          action_value?: string | null
          advertiser_name?: string
          body?: string | null
          click_count?: number
          created_at?: string
          created_by?: string | null
          ends_at?: string | null
          id?: string
          image_path?: string
          impression_count?: number
          placements?: string[]
          priority?: number
          region_ids?: number[] | null
          starts_at?: string
          status?: Database["public"]["Enums"]["promotion_status"]
          title?: string
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: []
      }
      rating_appeals: {
        Row: {
          created_at: string
          decided_at: string | null
          decided_by: string | null
          decision_note: string | null
          id: string
          rating_id: string
          reason: string
          seller_id: string
          status: string
        }
        Insert: {
          created_at?: string
          decided_at?: string | null
          decided_by?: string | null
          decision_note?: string | null
          id?: string
          rating_id: string
          reason: string
          seller_id: string
          status?: string
        }
        Update: {
          created_at?: string
          decided_at?: string | null
          decided_by?: string | null
          decision_note?: string | null
          id?: string
          rating_id?: string
          reason?: string
          seller_id?: string
          status?: string
        }
        Relationships: [
          {
            foreignKeyName: "rating_appeals_rating_id_fkey"
            columns: ["rating_id"]
            isOneToOne: true
            referencedRelation: "my_received_ratings"
            referencedColumns: ["rating_id"]
          },
          {
            foreignKeyName: "rating_appeals_rating_id_fkey"
            columns: ["rating_id"]
            isOneToOne: true
            referencedRelation: "public_ratings"
            referencedColumns: ["rating_id"]
          },
          {
            foreignKeyName: "rating_appeals_rating_id_fkey"
            columns: ["rating_id"]
            isOneToOne: true
            referencedRelation: "seller_ratings"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "rating_appeals_seller_id_fkey"
            columns: ["seller_id"]
            isOneToOne: false
            referencedRelation: "my_conversations"
            referencedColumns: ["other_user_id"]
          },
          {
            foreignKeyName: "rating_appeals_seller_id_fkey"
            columns: ["seller_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "rating_appeals_seller_id_fkey"
            columns: ["seller_id"]
            isOneToOne: false
            referencedRelation: "public_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      rating_replies: {
        Row: {
          body: string
          created_at: string
          edited_at: string | null
          rating_id: string
          seller_id: string
        }
        Insert: {
          body: string
          created_at?: string
          edited_at?: string | null
          rating_id: string
          seller_id: string
        }
        Update: {
          body?: string
          created_at?: string
          edited_at?: string | null
          rating_id?: string
          seller_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "rating_replies_rating_id_fkey"
            columns: ["rating_id"]
            isOneToOne: true
            referencedRelation: "my_received_ratings"
            referencedColumns: ["rating_id"]
          },
          {
            foreignKeyName: "rating_replies_rating_id_fkey"
            columns: ["rating_id"]
            isOneToOne: true
            referencedRelation: "public_ratings"
            referencedColumns: ["rating_id"]
          },
          {
            foreignKeyName: "rating_replies_rating_id_fkey"
            columns: ["rating_id"]
            isOneToOne: true
            referencedRelation: "seller_ratings"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "rating_replies_seller_id_fkey"
            columns: ["seller_id"]
            isOneToOne: false
            referencedRelation: "my_conversations"
            referencedColumns: ["other_user_id"]
          },
          {
            foreignKeyName: "rating_replies_seller_id_fkey"
            columns: ["seller_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "rating_replies_seller_id_fkey"
            columns: ["seller_id"]
            isOneToOne: false
            referencedRelation: "public_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      regions: {
        Row: {
          created_at: string
          id: number
          is_active: boolean
          name_ar: string
          sort_order: number
          updated_at: string
        }
        Insert: {
          created_at?: string
          id?: number
          is_active?: boolean
          name_ar: string
          sort_order?: number
          updated_at?: string
        }
        Update: {
          created_at?: string
          id?: number
          is_active?: boolean
          name_ar?: string
          sort_order?: number
          updated_at?: string
        }
        Relationships: []
      }
      report_evidence_access: {
        Row: {
          actor_id: string
          created_at: string
          id: number
          report_id: string
        }
        Insert: {
          actor_id: string
          created_at?: string
          id?: never
          report_id: string
        }
        Update: {
          actor_id?: string
          created_at?: string
          id?: never
          report_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "report_evidence_access_report_id_fkey"
            columns: ["report_id"]
            isOneToOne: false
            referencedRelation: "reports"
            referencedColumns: ["id"]
          },
        ]
      }
      reports: {
        Row: {
          assigned_to: string | null
          close_reason: string | null
          closed_at: string | null
          closed_by: string | null
          created_at: string
          description: string | null
          id: string
          internal_note: string | null
          listing_id: string | null
          reason: string
          ref: string
          reporter_id: string
          request_id: string
          response_text: string | null
          status: string
          target_id: string
          target_type: string
          target_user_id: string
          updated_at: string
        }
        Insert: {
          assigned_to?: string | null
          close_reason?: string | null
          closed_at?: string | null
          closed_by?: string | null
          created_at?: string
          description?: string | null
          id?: string
          internal_note?: string | null
          listing_id?: string | null
          reason: string
          ref?: string
          reporter_id: string
          request_id: string
          response_text?: string | null
          status?: string
          target_id: string
          target_type: string
          target_user_id: string
          updated_at?: string
        }
        Update: {
          assigned_to?: string | null
          close_reason?: string | null
          closed_at?: string | null
          closed_by?: string | null
          created_at?: string
          description?: string | null
          id?: string
          internal_note?: string | null
          listing_id?: string | null
          reason?: string
          ref?: string
          reporter_id?: string
          request_id?: string
          response_text?: string | null
          status?: string
          target_id?: string
          target_type?: string
          target_user_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "reports_listing_id_fkey"
            columns: ["listing_id"]
            isOneToOne: false
            referencedRelation: "listings"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "reports_listing_id_fkey"
            columns: ["listing_id"]
            isOneToOne: false
            referencedRelation: "my_listings"
            referencedColumns: ["listing_id"]
          },
          {
            foreignKeyName: "reports_listing_id_fkey"
            columns: ["listing_id"]
            isOneToOne: false
            referencedRelation: "public_listing_cards"
            referencedColumns: ["listing_id"]
          },
          {
            foreignKeyName: "reports_listing_id_fkey"
            columns: ["listing_id"]
            isOneToOne: false
            referencedRelation: "public_listing_details"
            referencedColumns: ["listing_id"]
          },
          {
            foreignKeyName: "reports_listing_id_fkey"
            columns: ["listing_id"]
            isOneToOne: false
            referencedRelation: "public_listing_media"
            referencedColumns: ["listing_id"]
          },
          {
            foreignKeyName: "reports_reporter_id_fkey"
            columns: ["reporter_id"]
            isOneToOne: false
            referencedRelation: "my_conversations"
            referencedColumns: ["other_user_id"]
          },
          {
            foreignKeyName: "reports_reporter_id_fkey"
            columns: ["reporter_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "reports_reporter_id_fkey"
            columns: ["reporter_id"]
            isOneToOne: false
            referencedRelation: "public_profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "reports_target_user_id_fkey"
            columns: ["target_user_id"]
            isOneToOne: false
            referencedRelation: "my_conversations"
            referencedColumns: ["other_user_id"]
          },
          {
            foreignKeyName: "reports_target_user_id_fkey"
            columns: ["target_user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "reports_target_user_id_fkey"
            columns: ["target_user_id"]
            isOneToOne: false
            referencedRelation: "public_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      reviews: {
        Row: {
          content_hash: string | null
          created_at: string
          decision: Database["public"]["Enums"]["review_decision"]
          id: number
          listing_id: string
          moderator_id: string
          reason_code: string | null
          reason_text: string | null
          version_id: string | null
        }
        Insert: {
          content_hash?: string | null
          created_at?: string
          decision: Database["public"]["Enums"]["review_decision"]
          id?: never
          listing_id: string
          moderator_id: string
          reason_code?: string | null
          reason_text?: string | null
          version_id?: string | null
        }
        Update: {
          content_hash?: string | null
          created_at?: string
          decision?: Database["public"]["Enums"]["review_decision"]
          id?: never
          listing_id?: string
          moderator_id?: string
          reason_code?: string | null
          reason_text?: string | null
          version_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "reviews_listing_id_fkey"
            columns: ["listing_id"]
            isOneToOne: false
            referencedRelation: "listings"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "reviews_listing_id_fkey"
            columns: ["listing_id"]
            isOneToOne: false
            referencedRelation: "my_listings"
            referencedColumns: ["listing_id"]
          },
          {
            foreignKeyName: "reviews_listing_id_fkey"
            columns: ["listing_id"]
            isOneToOne: false
            referencedRelation: "public_listing_cards"
            referencedColumns: ["listing_id"]
          },
          {
            foreignKeyName: "reviews_listing_id_fkey"
            columns: ["listing_id"]
            isOneToOne: false
            referencedRelation: "public_listing_details"
            referencedColumns: ["listing_id"]
          },
          {
            foreignKeyName: "reviews_listing_id_fkey"
            columns: ["listing_id"]
            isOneToOne: false
            referencedRelation: "public_listing_media"
            referencedColumns: ["listing_id"]
          },
          {
            foreignKeyName: "reviews_listing_id_version_id_fkey"
            columns: ["listing_id", "version_id"]
            isOneToOne: false
            referencedRelation: "listing_versions"
            referencedColumns: ["listing_id", "id"]
          },
          {
            foreignKeyName: "reviews_reason_code_fkey"
            columns: ["reason_code"]
            isOneToOne: false
            referencedRelation: "moderation_reasons"
            referencedColumns: ["code"]
          },
        ]
      }
      saved_searches: {
        Row: {
          created_at: string
          filters: Json
          filters_hash: string
          id: string
          name: string | null
          user_id: string
        }
        Insert: {
          created_at?: string
          filters: Json
          filters_hash: string
          id?: string
          name?: string | null
          user_id: string
        }
        Update: {
          created_at?: string
          filters?: Json
          filters_hash?: string
          id?: string
          name?: string | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "saved_searches_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "my_conversations"
            referencedColumns: ["other_user_id"]
          },
          {
            foreignKeyName: "saved_searches_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "saved_searches_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "public_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      seller_rating_history: {
        Row: {
          body: string | null
          id: number
          rating_id: string
          replaced_at: string
          score: number
        }
        Insert: {
          body?: string | null
          id?: never
          rating_id: string
          replaced_at?: string
          score: number
        }
        Update: {
          body?: string | null
          id?: never
          rating_id?: string
          replaced_at?: string
          score?: number
        }
        Relationships: [
          {
            foreignKeyName: "seller_rating_history_rating_id_fkey"
            columns: ["rating_id"]
            isOneToOne: false
            referencedRelation: "my_received_ratings"
            referencedColumns: ["rating_id"]
          },
          {
            foreignKeyName: "seller_rating_history_rating_id_fkey"
            columns: ["rating_id"]
            isOneToOne: false
            referencedRelation: "public_ratings"
            referencedColumns: ["rating_id"]
          },
          {
            foreignKeyName: "seller_rating_history_rating_id_fkey"
            columns: ["rating_id"]
            isOneToOne: false
            referencedRelation: "seller_ratings"
            referencedColumns: ["id"]
          },
        ]
      }
      seller_ratings: {
        Row: {
          body: string | null
          conversation_id: string
          created_at: string
          declaration_at: string
          edited_at: string | null
          hidden_at: string | null
          hidden_by: string | null
          hidden_reason_code: string | null
          hidden_reason_text: string | null
          id: string
          rater_id: string
          request_id: string
          score: number
          seller_id: string
          status: string
          updated_at: string
        }
        Insert: {
          body?: string | null
          conversation_id: string
          created_at?: string
          declaration_at: string
          edited_at?: string | null
          hidden_at?: string | null
          hidden_by?: string | null
          hidden_reason_code?: string | null
          hidden_reason_text?: string | null
          id?: string
          rater_id: string
          request_id: string
          score: number
          seller_id: string
          status?: string
          updated_at?: string
        }
        Update: {
          body?: string | null
          conversation_id?: string
          created_at?: string
          declaration_at?: string
          edited_at?: string | null
          hidden_at?: string | null
          hidden_by?: string | null
          hidden_reason_code?: string | null
          hidden_reason_text?: string | null
          id?: string
          rater_id?: string
          request_id?: string
          score?: number
          seller_id?: string
          status?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "seller_ratings_conversation_id_fkey"
            columns: ["conversation_id"]
            isOneToOne: false
            referencedRelation: "conversations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "seller_ratings_conversation_id_fkey"
            columns: ["conversation_id"]
            isOneToOne: false
            referencedRelation: "my_conversations"
            referencedColumns: ["conversation_id"]
          },
          {
            foreignKeyName: "seller_ratings_hidden_reason_code_fkey"
            columns: ["hidden_reason_code"]
            isOneToOne: false
            referencedRelation: "moderation_reasons"
            referencedColumns: ["code"]
          },
          {
            foreignKeyName: "seller_ratings_rater_id_fkey"
            columns: ["rater_id"]
            isOneToOne: false
            referencedRelation: "my_conversations"
            referencedColumns: ["other_user_id"]
          },
          {
            foreignKeyName: "seller_ratings_rater_id_fkey"
            columns: ["rater_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "seller_ratings_rater_id_fkey"
            columns: ["rater_id"]
            isOneToOne: false
            referencedRelation: "public_profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "seller_ratings_seller_id_fkey"
            columns: ["seller_id"]
            isOneToOne: false
            referencedRelation: "my_conversations"
            referencedColumns: ["other_user_id"]
          },
          {
            foreignKeyName: "seller_ratings_seller_id_fkey"
            columns: ["seller_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "seller_ratings_seller_id_fkey"
            columns: ["seller_id"]
            isOneToOne: false
            referencedRelation: "public_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      settings_versions: {
        Row: {
          content: Json
          note: string | null
          published_at: string
          published_by: string | null
          restored_from_version: number | null
          version: number
        }
        Insert: {
          content: Json
          note?: string | null
          published_at?: string
          published_by?: string | null
          restored_from_version?: number | null
          version: number
        }
        Update: {
          content?: Json
          note?: string | null
          published_at?: string
          published_by?: string | null
          restored_from_version?: number | null
          version?: number
        }
        Relationships: [
          {
            foreignKeyName: "settings_versions_restored_from_version_fkey"
            columns: ["restored_from_version"]
            isOneToOne: false
            referencedRelation: "settings_versions"
            referencedColumns: ["version"]
          },
        ]
      }
      user_blocks: {
        Row: {
          blocked_id: string
          blocker_id: string
          created_at: string
        }
        Insert: {
          blocked_id: string
          blocker_id: string
          created_at?: string
        }
        Update: {
          blocked_id?: string
          blocker_id?: string
          created_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "user_blocks_blocked_id_fkey"
            columns: ["blocked_id"]
            isOneToOne: false
            referencedRelation: "my_conversations"
            referencedColumns: ["other_user_id"]
          },
          {
            foreignKeyName: "user_blocks_blocked_id_fkey"
            columns: ["blocked_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "user_blocks_blocked_id_fkey"
            columns: ["blocked_id"]
            isOneToOne: false
            referencedRelation: "public_profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "user_blocks_blocker_id_fkey"
            columns: ["blocker_id"]
            isOneToOne: false
            referencedRelation: "my_conversations"
            referencedColumns: ["other_user_id"]
          },
          {
            foreignKeyName: "user_blocks_blocker_id_fkey"
            columns: ["blocker_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "user_blocks_blocker_id_fkey"
            columns: ["blocker_id"]
            isOneToOne: false
            referencedRelation: "public_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Views: {
      my_blocks: {
        Row: {
          blocked_at: string | null
          display_name: string | null
          user_id: string | null
        }
        Relationships: [
          {
            foreignKeyName: "user_blocks_blocked_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "my_conversations"
            referencedColumns: ["other_user_id"]
          },
          {
            foreignKeyName: "user_blocks_blocked_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "user_blocks_blocked_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "public_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      my_conversations: {
        Row: {
          conversation_id: string | null
          cover_bucket: string | null
          cover_path: string | null
          created_at: string | null
          last_message_at: string | null
          last_message_body: string | null
          last_message_sender_id: string | null
          listing_available: boolean | null
          listing_id: string | null
          listing_title: string | null
          muted: boolean | null
          my_role: string | null
          other_display_name: string | null
          other_user_id: string | null
          unread_count: number | null
          writable: boolean | null
        }
        Relationships: [
          {
            foreignKeyName: "conversations_listing_id_fkey"
            columns: ["listing_id"]
            isOneToOne: false
            referencedRelation: "listings"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "conversations_listing_id_fkey"
            columns: ["listing_id"]
            isOneToOne: false
            referencedRelation: "my_listings"
            referencedColumns: ["listing_id"]
          },
          {
            foreignKeyName: "conversations_listing_id_fkey"
            columns: ["listing_id"]
            isOneToOne: false
            referencedRelation: "public_listing_cards"
            referencedColumns: ["listing_id"]
          },
          {
            foreignKeyName: "conversations_listing_id_fkey"
            columns: ["listing_id"]
            isOneToOne: false
            referencedRelation: "public_listing_details"
            referencedColumns: ["listing_id"]
          },
          {
            foreignKeyName: "conversations_listing_id_fkey"
            columns: ["listing_id"]
            isOneToOne: false
            referencedRelation: "public_listing_media"
            referencedColumns: ["listing_id"]
          },
          {
            foreignKeyName: "messages_sender_id_fkey"
            columns: ["last_message_sender_id"]
            isOneToOne: false
            referencedRelation: "my_conversations"
            referencedColumns: ["other_user_id"]
          },
          {
            foreignKeyName: "messages_sender_id_fkey"
            columns: ["last_message_sender_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "messages_sender_id_fkey"
            columns: ["last_message_sender_id"]
            isOneToOne: false
            referencedRelation: "public_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      my_favorites: {
        Row: {
          age_months: number | null
          auction_lat: number | null
          auction_lng: number | null
          auction_passed: boolean | null
          auction_starts_at: string | null
          available: boolean | null
          breed_id: number | null
          breed_name_ar: string | null
          breed_note: string | null
          city_id: number | null
          city_name_ar: string | null
          cover_bucket: string | null
          cover_path: string | null
          favorite_count: number | null
          listing_id: string | null
          offer_type: Database["public"]["Enums"]["offer_type"] | null
          owner_display_name: string | null
          owner_id: string | null
          price: number | null
          public_ref: string | null
          region_id: number | null
          region_name_ar: string | null
          saved_at: string | null
          sex: Database["public"]["Enums"]["animal_sex"] | null
          title: string | null
          view_count: number | null
        }
        Relationships: [
          {
            foreignKeyName: "favorites_listing_id_fkey"
            columns: ["listing_id"]
            isOneToOne: false
            referencedRelation: "listings"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "favorites_listing_id_fkey"
            columns: ["listing_id"]
            isOneToOne: false
            referencedRelation: "my_listings"
            referencedColumns: ["listing_id"]
          },
          {
            foreignKeyName: "favorites_listing_id_fkey"
            columns: ["listing_id"]
            isOneToOne: false
            referencedRelation: "public_listing_cards"
            referencedColumns: ["listing_id"]
          },
          {
            foreignKeyName: "favorites_listing_id_fkey"
            columns: ["listing_id"]
            isOneToOne: false
            referencedRelation: "public_listing_details"
            referencedColumns: ["listing_id"]
          },
          {
            foreignKeyName: "favorites_listing_id_fkey"
            columns: ["listing_id"]
            isOneToOne: false
            referencedRelation: "public_listing_media"
            referencedColumns: ["listing_id"]
          },
          {
            foreignKeyName: "listing_versions_breed_id_fkey"
            columns: ["breed_id"]
            isOneToOne: false
            referencedRelation: "breeds"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "listing_versions_city_id_region_id_fkey"
            columns: ["city_id", "region_id"]
            isOneToOne: false
            referencedRelation: "cities"
            referencedColumns: ["id", "region_id"]
          },
          {
            foreignKeyName: "listing_versions_region_id_fkey"
            columns: ["region_id"]
            isOneToOne: false
            referencedRelation: "regions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "listings_owner_id_fkey"
            columns: ["owner_id"]
            isOneToOne: false
            referencedRelation: "my_conversations"
            referencedColumns: ["other_user_id"]
          },
          {
            foreignKeyName: "listings_owner_id_fkey"
            columns: ["owner_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "listings_owner_id_fkey"
            columns: ["owner_id"]
            isOneToOne: false
            referencedRelation: "public_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      my_follows: {
        Row: {
          display_name: string | null
          followed_at: string | null
          published_listings_count: number | null
          region_id: number | null
          region_name_ar: string | null
          user_id: string | null
        }
        Relationships: [
          {
            foreignKeyName: "follows_seller_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "my_conversations"
            referencedColumns: ["other_user_id"]
          },
          {
            foreignKeyName: "follows_seller_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "follows_seller_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "public_profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "profiles_region_id_fkey"
            columns: ["region_id"]
            isOneToOne: false
            referencedRelation: "regions"
            referencedColumns: ["id"]
          },
        ]
      }
      my_listings: {
        Row: {
          auction_passed: boolean | null
          auction_starts_at: string | null
          cover_bucket: string | null
          cover_path: string | null
          created_at: string | null
          current_version_id: string | null
          favorite_count: number | null
          first_published_at: string | null
          first_submitted_at: string | null
          has_draft: boolean | null
          last_bumped_at: string | null
          last_published_at: string | null
          listing_id: string | null
          next_bump_at: string | null
          offer_type: Database["public"]["Enums"]["offer_type"] | null
          price: number | null
          published_version_id: string | null
          reason_code: string | null
          reason_decided_at: string | null
          reason_label_ar: string | null
          reason_text: string | null
          status: Database["public"]["Enums"]["listing_status"] | null
          status_changed_at: string | null
          title: string | null
          updated_at: string | null
          version_no: number | null
          version_status:
            | Database["public"]["Enums"]["listing_version_status"]
            | null
          view_count: number | null
        }
        Relationships: [
          {
            foreignKeyName: "listings_current_version_fk"
            columns: ["listing_id", "current_version_id"]
            isOneToOne: false
            referencedRelation: "listing_versions"
            referencedColumns: ["listing_id", "id"]
          },
          {
            foreignKeyName: "listings_published_version_fk"
            columns: ["listing_id", "published_version_id"]
            isOneToOne: false
            referencedRelation: "listing_versions"
            referencedColumns: ["listing_id", "id"]
          },
          {
            foreignKeyName: "reviews_reason_code_fkey"
            columns: ["reason_code"]
            isOneToOne: false
            referencedRelation: "moderation_reasons"
            referencedColumns: ["code"]
          },
        ]
      }
      my_notification_preferences: {
        Row: {
          category: string | null
          push_enabled: boolean | null
        }
        Relationships: []
      }
      my_received_ratings: {
        Row: {
          appeal_id: string | null
          appeal_status: string | null
          body: string | null
          created_at: string | null
          edited_at: string | null
          rater_display_name: string | null
          rater_id: string | null
          rating_id: string | null
          reply_body: string | null
          score: number | null
          status: string | null
        }
        Relationships: [
          {
            foreignKeyName: "seller_ratings_rater_id_fkey"
            columns: ["rater_id"]
            isOneToOne: false
            referencedRelation: "my_conversations"
            referencedColumns: ["other_user_id"]
          },
          {
            foreignKeyName: "seller_ratings_rater_id_fkey"
            columns: ["rater_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "seller_ratings_rater_id_fkey"
            columns: ["rater_id"]
            isOneToOne: false
            referencedRelation: "public_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      my_saved_searches: {
        Row: {
          created_at: string | null
          filters: Json | null
          id: string | null
          name: string | null
        }
        Insert: {
          created_at?: string | null
          filters?: Json | null
          id?: string | null
          name?: string | null
        }
        Update: {
          created_at?: string | null
          filters?: Json | null
          id?: string | null
          name?: string | null
        }
        Relationships: []
      }
      public_comments: {
        Row: {
          author_display_name: string | null
          author_id: string | null
          body: string | null
          comment_id: string | null
          created_at: string | null
          edited_at: string | null
          is_owner: boolean | null
          listing_id: string | null
          parent_id: string | null
          state: string | null
        }
        Relationships: [
          {
            foreignKeyName: "comments_author_id_fkey"
            columns: ["author_id"]
            isOneToOne: false
            referencedRelation: "my_conversations"
            referencedColumns: ["other_user_id"]
          },
          {
            foreignKeyName: "comments_author_id_fkey"
            columns: ["author_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "comments_author_id_fkey"
            columns: ["author_id"]
            isOneToOne: false
            referencedRelation: "public_profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "comments_listing_id_fkey"
            columns: ["listing_id"]
            isOneToOne: false
            referencedRelation: "listings"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "comments_listing_id_fkey"
            columns: ["listing_id"]
            isOneToOne: false
            referencedRelation: "my_listings"
            referencedColumns: ["listing_id"]
          },
          {
            foreignKeyName: "comments_listing_id_fkey"
            columns: ["listing_id"]
            isOneToOne: false
            referencedRelation: "public_listing_cards"
            referencedColumns: ["listing_id"]
          },
          {
            foreignKeyName: "comments_listing_id_fkey"
            columns: ["listing_id"]
            isOneToOne: false
            referencedRelation: "public_listing_details"
            referencedColumns: ["listing_id"]
          },
          {
            foreignKeyName: "comments_listing_id_fkey"
            columns: ["listing_id"]
            isOneToOne: false
            referencedRelation: "public_listing_media"
            referencedColumns: ["listing_id"]
          },
          {
            foreignKeyName: "comments_parent_id_fkey"
            columns: ["parent_id"]
            isOneToOne: false
            referencedRelation: "comments"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "comments_parent_id_fkey"
            columns: ["parent_id"]
            isOneToOne: false
            referencedRelation: "public_comments"
            referencedColumns: ["comment_id"]
          },
        ]
      }
      public_listing_cards: {
        Row: {
          age_months: number | null
          auction_lat: number | null
          auction_lng: number | null
          auction_passed: boolean | null
          auction_starts_at: string | null
          breed_id: number | null
          breed_name_ar: string | null
          breed_note: string | null
          city_id: number | null
          city_name_ar: string | null
          cover_bucket: string | null
          cover_path: string | null
          favorite_count: number | null
          first_published_at: string | null
          listing_id: string | null
          offer_type: Database["public"]["Enums"]["offer_type"] | null
          owner_display_name: string | null
          owner_id: string | null
          price: number | null
          public_ref: string | null
          region_id: number | null
          region_name_ar: string | null
          sex: Database["public"]["Enums"]["animal_sex"] | null
          title: string | null
          view_count: number | null
          visibility_updated_at: string | null
        }
        Relationships: [
          {
            foreignKeyName: "listing_versions_breed_id_fkey"
            columns: ["breed_id"]
            isOneToOne: false
            referencedRelation: "breeds"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "listing_versions_city_id_region_id_fkey"
            columns: ["city_id", "region_id"]
            isOneToOne: false
            referencedRelation: "cities"
            referencedColumns: ["id", "region_id"]
          },
          {
            foreignKeyName: "listing_versions_region_id_fkey"
            columns: ["region_id"]
            isOneToOne: false
            referencedRelation: "regions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "listings_owner_id_fkey"
            columns: ["owner_id"]
            isOneToOne: false
            referencedRelation: "my_conversations"
            referencedColumns: ["other_user_id"]
          },
          {
            foreignKeyName: "listings_owner_id_fkey"
            columns: ["owner_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "listings_owner_id_fkey"
            columns: ["owner_id"]
            isOneToOne: false
            referencedRelation: "public_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      public_listing_details: {
        Row: {
          age_months: number | null
          auction_city_id: number | null
          auction_city_name_ar: string | null
          auction_lat: number | null
          auction_lng: number | null
          auction_passed: boolean | null
          auction_region_id: number | null
          auction_region_name_ar: string | null
          auction_starts_at: string | null
          auction_venue: string | null
          breed_id: number | null
          breed_name_ar: string | null
          breed_note: string | null
          city_id: number | null
          city_name_ar: string | null
          color: string | null
          comments_closed: boolean | null
          contact_call_enabled: boolean | null
          contact_phone: string | null
          contact_whatsapp_enabled: boolean | null
          contact_whatsapp_phone: string | null
          description: string | null
          favorite_count: number | null
          first_published_at: string | null
          health_notes: string | null
          listing_id: string | null
          offer_type: Database["public"]["Enums"]["offer_type"] | null
          owner_display_name: string | null
          owner_id: string | null
          owner_joined_at: string | null
          price: number | null
          public_ref: string | null
          published_version_at: string | null
          region_id: number | null
          region_name_ar: string | null
          sex: Database["public"]["Enums"]["animal_sex"] | null
          title: string | null
          view_count: number | null
          visibility_updated_at: string | null
        }
        Relationships: [
          {
            foreignKeyName: "listing_versions_auction_city_id_auction_region_id_fkey"
            columns: ["auction_city_id", "auction_region_id"]
            isOneToOne: false
            referencedRelation: "cities"
            referencedColumns: ["id", "region_id"]
          },
          {
            foreignKeyName: "listing_versions_auction_region_id_fkey"
            columns: ["auction_region_id"]
            isOneToOne: false
            referencedRelation: "regions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "listing_versions_breed_id_fkey"
            columns: ["breed_id"]
            isOneToOne: false
            referencedRelation: "breeds"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "listing_versions_city_id_region_id_fkey"
            columns: ["city_id", "region_id"]
            isOneToOne: false
            referencedRelation: "cities"
            referencedColumns: ["id", "region_id"]
          },
          {
            foreignKeyName: "listing_versions_region_id_fkey"
            columns: ["region_id"]
            isOneToOne: false
            referencedRelation: "regions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "listings_owner_id_fkey"
            columns: ["owner_id"]
            isOneToOne: false
            referencedRelation: "my_conversations"
            referencedColumns: ["other_user_id"]
          },
          {
            foreignKeyName: "listings_owner_id_fkey"
            columns: ["owner_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "listings_owner_id_fkey"
            columns: ["owner_id"]
            isOneToOne: false
            referencedRelation: "public_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      public_listing_media: {
        Row: {
          bucket: string | null
          duration_seconds: number | null
          height: number | null
          is_cover: boolean | null
          kind: Database["public"]["Enums"]["media_kind"] | null
          listing_id: string | null
          media_id: string | null
          mime_type: string | null
          object_path: string | null
          sort_order: number | null
          width: number | null
        }
        Relationships: []
      }
      public_profiles: {
        Row: {
          display_name: string | null
          id: string | null
          joined_at: string | null
          published_listings_count: number | null
          rating_avg: number | null
          rating_count: number | null
          region_id: number | null
          region_name_ar: string | null
        }
        Relationships: [
          {
            foreignKeyName: "profiles_region_id_fkey"
            columns: ["region_id"]
            isOneToOne: false
            referencedRelation: "regions"
            referencedColumns: ["id"]
          },
        ]
      }
      public_ratings: {
        Row: {
          body: string | null
          created_at: string | null
          edited_at: string | null
          rater_display_name: string | null
          rater_id: string | null
          rating_id: string | null
          reply_at: string | null
          reply_body: string | null
          score: number | null
          seller_id: string | null
        }
        Relationships: [
          {
            foreignKeyName: "seller_ratings_rater_id_fkey"
            columns: ["rater_id"]
            isOneToOne: false
            referencedRelation: "my_conversations"
            referencedColumns: ["other_user_id"]
          },
          {
            foreignKeyName: "seller_ratings_rater_id_fkey"
            columns: ["rater_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "seller_ratings_rater_id_fkey"
            columns: ["rater_id"]
            isOneToOne: false
            referencedRelation: "public_profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "seller_ratings_seller_id_fkey"
            columns: ["seller_id"]
            isOneToOne: false
            referencedRelation: "my_conversations"
            referencedColumns: ["other_user_id"]
          },
          {
            foreignKeyName: "seller_ratings_seller_id_fkey"
            columns: ["seller_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "seller_ratings_seller_id_fkey"
            columns: ["seller_id"]
            isOneToOne: false
            referencedRelation: "public_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Functions: {
      accept_policies: { Args: { p_document_ids: number[] }; Returns: Json }
      add_favorite: { Args: { p_listing_id: string }; Returns: Json }
      add_listing_media: {
        Args: {
          p_kind: Database["public"]["Enums"]["media_kind"]
          p_listing_id: string
          p_mime_type: string
          p_size_bytes: number
        }
        Returns: Json
      }
      admin_approve_listing_version: {
        Args: {
          p_content_hash: string
          p_listing_id: string
          p_version_id: string
        }
        Returns: Json
      }
      admin_assign_report: {
        Args: { p_assignee?: string; p_report_id: string }
        Returns: Json
      }
      admin_close_report: {
        Args: {
          p_close_reason: string
          p_internal_note?: string
          p_report_id: string
          p_response_text?: string
        }
        Returns: Json
      }
      admin_decide_rating_appeal: {
        Args: {
          p_appeal_id: string
          p_decision: string
          p_note?: string
          p_reason_code?: string
        }
        Returns: Json
      }
      admin_get_account: { Args: { p_user_id: string }; Returns: Json }
      admin_get_listing_review: {
        Args: { p_listing_id: string }
        Returns: Json
      }
      admin_get_promotion: { Args: { p_id: string }; Returns: Json }
      admin_get_promotion_settings: { Args: never; Returns: Json }
      admin_get_report_evidence: {
        Args: { p_report_id: string }
        Returns: Json
      }
      admin_get_settings: { Args: never; Returns: Json }
      admin_grant_role: {
        Args: {
          p_capabilities?: string[]
          p_role: Database["public"]["Enums"]["staff_role"]
          p_user_id: string
        }
        Returns: Json
      }
      admin_hide_comment: {
        Args: {
          p_comment_id: string
          p_reason_code: string
          p_reason_text?: string
        }
        Returns: Json
      }
      admin_hide_listing: {
        Args: {
          p_listing_id: string
          p_reason_code: string
          p_reason_text?: string
        }
        Returns: Json
      }
      admin_hide_rating: {
        Args: {
          p_rating_id: string
          p_reason_code: string
          p_reason_text?: string
        }
        Returns: Json
      }
      admin_list_listings: {
        Args: {
          p_after_changed_at?: string
          p_after_id?: string
          p_limit?: number
          p_query?: string
          p_status?: string
        }
        Returns: Json
      }
      admin_list_promotions: {
        Args: {
          p_after_id?: string
          p_after_updated_at?: string
          p_limit?: number
          p_status?: string
        }
        Returns: Json
      }
      admin_publish_settings: { Args: { p_note?: string }; Returns: Json }
      admin_reactivate_account: {
        Args: { p_note?: string; p_user_id: string }
        Returns: Json
      }
      admin_reject_listing_version: {
        Args: {
          p_content_hash: string
          p_listing_id: string
          p_reason_code: string
          p_reason_text?: string
          p_version_id: string
        }
        Returns: Json
      }
      admin_reorder_lookup: {
        Args: { p_ids: string[]; p_kind: string }
        Returns: Json
      }
      admin_review_queue: {
        Args: {
          p_after_changed_at?: string
          p_after_id?: string
          p_limit?: number
        }
        Returns: Json
      }
      admin_revoke_role: {
        Args: { p_reason?: string; p_user_id: string }
        Returns: Json
      }
      admin_rollback_settings: {
        Args: { p_note?: string; p_version: number }
        Returns: Json
      }
      admin_save_promotion: {
        Args: { p_id?: string; p_payload?: Json }
        Returns: Json
      }
      admin_set_lookup_active: {
        Args: { p_id: string; p_is_active: boolean; p_kind: string }
        Returns: Json
      }
      admin_set_promotion_status: {
        Args: { p_id: string; p_note?: string; p_status: string }
        Returns: Json
      }
      admin_set_report_status: {
        Args: { p_note?: string; p_report_id: string; p_status: string }
        Returns: Json
      }
      admin_stats: { Args: { p_from?: string; p_to?: string }; Returns: Json }
      admin_suspend_account: {
        Args: {
          p_reason_code: string
          p_reason_text?: string
          p_user_id: string
        }
        Returns: Json
      }
      admin_unhide_comment: {
        Args: { p_comment_id: string; p_note?: string }
        Returns: Json
      }
      admin_unhide_listing: {
        Args: { p_listing_id: string; p_note?: string }
        Returns: Json
      }
      admin_unhide_rating: {
        Args: { p_note?: string; p_rating_id: string }
        Returns: Json
      }
      admin_update_promotion_settings: {
        Args: { p_enabled: boolean; p_feed_interval: number }
        Returns: Json
      }
      admin_update_settings_draft: { Args: { p_content: Json }; Returns: Json }
      admin_upsert_breed: {
        Args: {
          p_id: number
          p_name_ar: string
          p_requires_note?: boolean
          p_sort_order?: number
        }
        Returns: Json
      }
      admin_upsert_city: {
        Args: {
          p_id: number
          p_name_ar: string
          p_region_id: number
          p_sort_order?: number
        }
        Returns: Json
      }
      admin_upsert_moderation_reason: {
        Args: {
          p_applies_to: string[]
          p_code: string
          p_label_ar: string
          p_requires_note?: boolean
          p_sort_order?: number
        }
        Returns: Json
      }
      admin_upsert_region: {
        Args: { p_id: number; p_name_ar: string; p_sort_order?: number }
        Returns: Json
      }
      admin_whoami: { Args: never; Returns: Json }
      appeal_rating: {
        Args: { p_rating_id: string; p_reason: string }
        Returns: Json
      }
      archive_listing: { Args: { p_listing_id: string }; Returns: Json }
      arrange_listing_media: {
        Args: {
          p_cover_id: string
          p_listing_id: string
          p_media_ids: string[]
        }
        Returns: Json
      }
      block_user: { Args: { p_user_id: string }; Returns: Json }
      bump_listing: { Args: { p_listing_id: string }; Returns: Json }
      claim_push_batch: { Args: { p_limit?: number }; Returns: Json }
      complete_push: {
        Args: {
          p_error?: string
          p_invalid_tokens?: string[]
          p_outbox_id: number
          p_status: string
        }
        Returns: undefined
      }
      create_listing_draft: { Args: { p_request_id: string }; Returns: Json }
      delete_comment: { Args: { p_comment_id: string }; Returns: Json }
      delete_listing: { Args: { p_listing_id: string }; Returns: Json }
      delete_saved_search: { Args: { p_id: string }; Returns: Json }
      discard_listing_edit: { Args: { p_listing_id: string }; Returns: Json }
      edit_comment: {
        Args: { p_body: string; p_comment_id: string }
        Returns: Json
      }
      edit_rating: {
        Args: { p_body: string; p_rating_id: string; p_score: number }
        Returns: Json
      }
      finalize_listing_media: {
        Args: {
          p_duration_seconds?: number
          p_failure_reason?: string
          p_height?: number
          p_media_id: string
          p_mime_type: string
          p_size_bytes: number
          p_width?: number
        }
        Returns: Json
      }
      follow_seller: { Args: { p_user_id: string }; Returns: Json }
      get_current_policies: { Args: never; Returns: Json }
      get_listing: { Args: { p_listing_id: string }; Returns: Json }
      get_my_account: { Args: never; Returns: Json }
      get_published_settings: { Args: never; Returns: Json }
      get_rating_eligibility: { Args: { p_seller_id: string }; Returns: Json }
      get_report_status: { Args: { p_report_id: string }; Returns: Json }
      has_staff_capability: { Args: { p_capability: string }; Returns: boolean }
      list_active_promotions: {
        Args: { p_placement: string; p_region_id?: number }
        Returns: Json
      }
      mark_conversation_read: {
        Args: { p_conversation_id: string }
        Returns: Json
      }
      mark_notifications_read: { Args: { p_ids?: string[] }; Returns: number }
      post_comment: {
        Args: {
          p_body: string
          p_listing_id: string
          p_parent_id?: string
          p_request_id: string
        }
        Returns: Json
      }
      record_listing_view: {
        Args: { p_device_id?: string; p_listing_id: string }
        Returns: number
      }
      record_promotion_event: {
        Args: { p_device_id?: string; p_kind: string; p_promotion_id: string }
        Returns: boolean
      }
      register_device_token: {
        Args: { p_platform: string; p_token: string }
        Returns: Json
      }
      remove_favorite: { Args: { p_listing_id: string }; Returns: Json }
      remove_listing_media: { Args: { p_media_id: string }; Returns: Json }
      reply_to_rating: {
        Args: { p_body: string; p_rating_id: string }
        Returns: Json
      }
      resolve_listing_ref: { Args: { p_ref: string }; Returns: string }
      save_listing_draft: {
        Args: { p_listing_id: string; p_patch: Json }
        Returns: Json
      }
      save_search: { Args: { p_filters: Json; p_name?: string }; Returns: Json }
      search_listings: {
        Args: {
          p_age_max?: number
          p_age_min?: number
          p_breed_id?: number
          p_city_id?: number
          p_cursor?: Json
          p_limit?: number
          p_offer_type?: string
          p_owner_id?: string
          p_price_max?: number
          p_price_min?: number
          p_query?: string
          p_region_id?: number
          p_sex?: string
          p_sort?: string
        }
        Returns: Json
      }
      send_message: {
        Args: {
          p_body: string
          p_conversation_id: string
          p_request_id: string
        }
        Returns: Json
      }
      set_comments_closed: {
        Args: { p_closed: boolean; p_listing_id: string }
        Returns: Json
      }
      set_conversation_muted: {
        Args: { p_conversation_id: string; p_muted: boolean }
        Returns: Json
      }
      set_my_avatar: { Args: { p_path: string }; Returns: Json }
      set_notification_preference: {
        Args: { p_category: string; p_push_enabled: boolean }
        Returns: Json
      }
      start_conversation: { Args: { p_listing_id: string }; Returns: Json }
      start_listing_edit: { Args: { p_listing_id: string }; Returns: Json }
      storage_object_is_public: {
        Args: { p_bucket: string; p_name: string }
        Returns: boolean
      }
      submit_listing: {
        Args: { p_listing_id: string; p_request_id: string }
        Returns: Json
      }
      submit_rating: {
        Args: {
          p_body: string
          p_declaration: boolean
          p_request_id: string
          p_score: number
          p_seller_id: string
        }
        Returns: Json
      }
      submit_report: {
        Args: {
          p_description: string
          p_reason: string
          p_request_id: string
          p_target_id: string
          p_target_type: string
        }
        Returns: Json
      }
      unblock_user: { Args: { p_user_id: string }; Returns: Json }
      unfollow_seller: { Args: { p_user_id: string }; Returns: Json }
      unregister_device_token: { Args: { p_token: string }; Returns: Json }
      update_my_profile: {
        Args: { p_display_name: string; p_region_id: number }
        Returns: Json
      }
    }
    Enums: {
      account_status: "ACTIVE" | "SUSPENDED"
      animal_sex: "MALE" | "FEMALE"
      listing_status:
        | "DRAFT"
        | "UNDER_REVIEW"
        | "REJECTED"
        | "PUBLISHED"
        | "HIDDEN"
        | "ARCHIVED"
      listing_version_status: "DRAFT" | "SUBMITTED" | "APPROVED" | "REJECTED"
      media_kind: "IMAGE" | "VIDEO"
      media_status: "PENDING" | "READY" | "FAILED"
      notification_category:
        | "LISTING_STATUS"
        | "ACCOUNT"
        | "REPORTS"
        | "FOLLOWS"
        | "MESSAGES"
        | "COMMENTS"
        | "RATINGS"
      offer_type: "FIXED_PRICE" | "IN_PERSON_AUCTION"
      policy_kind: "TERMS" | "PRIVACY"
      promotion_action: "URL" | "WHATSAPP" | "CALL" | "NONE"
      promotion_status: "ACTIVE" | "PAUSED" | "ARCHIVED"
      review_decision: "APPROVED" | "REJECTED" | "HIDDEN" | "UNHIDDEN"
      staff_role: "MODERATOR" | "ADMIN"
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  graphql_public: {
    Enums: {},
  },
  public: {
    Enums: {
      account_status: ["ACTIVE", "SUSPENDED"],
      animal_sex: ["MALE", "FEMALE"],
      listing_status: [
        "DRAFT",
        "UNDER_REVIEW",
        "REJECTED",
        "PUBLISHED",
        "HIDDEN",
        "ARCHIVED",
      ],
      listing_version_status: ["DRAFT", "SUBMITTED", "APPROVED", "REJECTED"],
      media_kind: ["IMAGE", "VIDEO"],
      media_status: ["PENDING", "READY", "FAILED"],
      notification_category: [
        "LISTING_STATUS",
        "ACCOUNT",
        "REPORTS",
        "FOLLOWS",
        "MESSAGES",
        "COMMENTS",
        "RATINGS",
      ],
      offer_type: ["FIXED_PRICE", "IN_PERSON_AUCTION"],
      policy_kind: ["TERMS", "PRIVACY"],
      promotion_action: ["URL", "WHATSAPP", "CALL", "NONE"],
      promotion_status: ["ACTIVE", "PAUSED", "ARCHIVED"],
      review_decision: ["APPROVED", "REJECTED", "HIDDEN", "UNHIDDEN"],
      staff_role: ["MODERATOR", "ADMIN"],
    },
  },
} as const

