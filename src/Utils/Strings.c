#include <stdlib.h>
#include <string.h>
#include <glib.h>

#ifndef NAME_MAX
# define NAME_MAX 255
#endif
#define PART_TYPE_DIGIT 0
#define PART_TYPE_NONDIGIT 1
#define PART_TYPE_EMPTY 2

struct StrPart {
    int type;
    int length;
    gchar *data;
};

gchar* tatap_string_get_next_part(gchar* str, struct StrPart* part);
int tatap_string_compare_nondigit(gchar *str_a, gchar *str_b);
int tatap_string_last_index_of_char(gchar *str, gchar needle);

/**
 * The string (filename) comparison function.
 * This function compares two strings so that the number part of the string is correct in the order of the numbers.
 */
int tatap_filename_compare(gchar* str_a, gchar* str_b) {
    int last_dot_a = tatap_string_last_index_of_char(str_a, '.');
    int last_dot_b = tatap_string_last_index_of_char(str_b, '.');
    gchar *name_a = g_strndup(str_a, last_dot_a);
    gchar *name_b = g_strndup(str_b, last_dot_b);
    struct StrPart part_a = {0};
    struct StrPart part_b = {0};
    int result = 0;
    gchar *next_a = name_a, *next_b = name_b;
    int end_flag = 0;
    do {
        next_a = tatap_string_get_next_part(next_a, &part_a);
        next_b = tatap_string_get_next_part(next_b, &part_b);
        if (part_a.type == PART_TYPE_EMPTY) {
            if (part_b.type == PART_TYPE_EMPTY) {
                result = 0;
                end_flag = 1;
            } else {
                result = -1;
                end_flag = 1;
                g_free(part_b.data);
            }
        } else if (part_b.type == PART_TYPE_EMPTY) {
            result = 1;
            end_flag = 1;
            g_free(part_a.data);
        } else {
            if (part_a.type == PART_TYPE_DIGIT && part_b.type == PART_TYPE_DIGIT) {
                int int_a = atoi(part_a.data);
                int int_b = atoi(part_b.data);
                result = int_a - int_b;
            } else {
                result = g_ascii_strncasecmp(part_a.data, part_b.data, NAME_MAX);
            }
            g_free(part_a.data);
            g_free(part_b.data);
        }
    } while (result == 0 && end_flag == 0);
    g_free(name_a);
    g_free(name_b);
    if (result == 0) {
        gchar *ext_a = str_a + last_dot_a + 1;
        gchar *ext_b = str_b + last_dot_b + 1;
        result = strcmp(ext_a, ext_b);
    }
    return result;
}

gchar* tatap_string_get_next_part(gchar* str, struct StrPart* part) {
    if (str[0] == '\0') {
        part->type = PART_TYPE_EMPTY;
        part->length = 0;
        part->data = NULL;
        return NULL;
    }
    int type = g_ascii_isdigit(str[0]) ? PART_TYPE_DIGIT : PART_TYPE_NONDIGIT;
    int prev_type = type;
    int i = 1;
    do {
        if (str[i] == '\0') {
            i++;
            break;
        }
        prev_type = type;
        type = g_ascii_isdigit(str[i]) ? PART_TYPE_DIGIT : PART_TYPE_NONDIGIT;
        i++;
    } while (prev_type == type);
    part->type = prev_type;
    part->data = g_strndup(str, i - 1);
    part->length = i - 1;
    return str + i - 1;
}

int tatap_string_last_index_of_char(gchar *str, gchar needle) {
    int len = strlen(str);
    for (int i = len - 1; i >= 0; i--) {
        if (str[i] == needle) {
            return i;
        }
    }
    return -1;
}