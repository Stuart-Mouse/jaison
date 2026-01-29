
#add_context jaison: Jaison_Context;

// TODO: since we are adding a context, we may as well use it for the rename proc and float handling...
Jaison_Context :: struct {
    type_handlers: [..] JSON_Type_Handler;
}

/*
    I am not 100% satisfied with the design of handlers here, but this is the best I could come up with in light of the need for a split between preparing the slot and actually setting the value.
    Maybe we don't really need that split and could just handle everything all at once, but that would require more extensive changes.
    
    Because of the split between preparing the slot and actually writing to it, we need to be able to attach some kind of user data in prepare_slot that we can read in get_member_slot or set_value_from_string.
    And, since we are potentially way down in some recursive structure, our only option for allocating that user data is most likely to New() it.
    So now that we have some user data that may (or may not!) be dynamically allocated, we need a means to free that later, hence the deinit proc.
    
    One plus to doing things this way is that we could override any of the handler procs on a per-instance basis, but how useful that really is is up for debate.
*/

JSON_Type_Handler :: struct {
    type:                   *Type_Info;
    user_data:              *void;
    
    prepare_slot:           (handler: *JSON_Type_Handler, expected_type: Type_Info_Tag, info: *Type_Info, slot: *void) -> success: bool, info: *Type_Info, slot: *void; 
    get_member_slot:        (handler: *JSON_Type_Handler, info: *Type_Info, slot: *void, key: string, index: int) -> success: bool, info: *Type_Info, slot: *void;
    set_value_from_string:  (handler: *JSON_Type_Handler, info: *Type_Info, slot: *void, string_value: string) -> success: bool;
    deinit:                 (handler: *JSON_Type_Handler);
}

is_valid :: inline (handler: JSON_Type_Handler) -> bool { 
    return handler.type != null;
}

deinit :: inline (handler: *JSON_Type_Handler) {
    if is_valid(handler) {
        if handler.deinit  handler.deinit(handler);
        handler.* = .{};
    }
}

get_handler_for_type :: (info: *Type_Info) -> JSON_Type_Handler {
    handlers := context.jaison.type_handlers;
    if !handlers  return .{};
    
    // first iteration searches for specific type, repeating search if type is a variant
    while true {
        for handler: handlers {
            if handler.type == info {
                return handler;
            }
        }
        if info.type == .VARIANT {
            info = (cast(*Type_Info_Variant) info).variant_of;
            continue;
        }
        break;
    }
    
    // second iteration searches for match to polymorph_source_struct
    if info.type == .STRUCT {
        polymorph_source_struct := (cast(*Type_Info_Struct) info).polymorph_source_struct;
        for handler: handlers {
            if handler.type == xx polymorph_source_struct {
                return handler;
            }
        }
    }
    
    return .{};
}

// With a generic handler interface, you have options now as to whether you want to use a handler for Any_Hash_Table, or generate individual handlers for specific hash table types.
// You can also handle things like Fixed_Array and Fixed_String types, or even bucket arrays and the like.
