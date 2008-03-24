#!/bin/sh
#
#	$Id: mgd77netcdfhelper.sh,v 1.22 2008-03-24 08:58:32 guru Exp $
#
#	Author:		P. Wessel
#	Date:		2005-OCT-14
#	Revised:	2007-JUN-06: Now store _REVISED attributes set by E77
#
# This script will automatically create three functions from info in mgd77.h:
#
# MGD77_Read_Header_Params	: Read the MGD77 header attributes from the netCDF file
# MGD77_Write_Header_Params	: Write the MGD77 header attributes to the netCDF file
# MGD77_Dump_Header_Params	: Display individual header attributes, one per line
#
# Code is placed in the file mgd77_functions.h which is included in mgd77.c
#
# The script is run when needed by the makefile
#

cat << EOF > mgd77_functions.h
/* Code automatically generated by mgd77netcdfhelper.sh
 * To be included by mgd77.h
 *
 *    Copyright (c) 2005-2008 by P. Wessel
 *    See README file for copying and redistribution conditions.
 */

struct MGD77_HEADER_LOOKUP {		/* Book-keeping for one header parameter  */
	char name[64];		/* Name of this parameter (e.g., "Gravity_Sampling_Rate") */
	GMT_LONG length;		/* Number of bytes to use */
	int record;		/* Header record number where it occurs (1-24) */
	int item;		/* Sequential item order in this record (1->) */
	BOOLEAN check;		/* TRUE if we actually do a test on this item */
	char *ptr;		/* Pointer to the corresponding named variable in struct MGD77_HEADER_PARAMS */
};

struct MGD77_HEADER_PARAMS {		/* See MGD-77 Documentation from NGDC for details */
	/* Sequence No 01: */
	char	Record_Type;
EOF

cat << EOF > mgd77_functions.c
/* Code automatically generated by mgd77netcdfhelper.sh
 * To be included by mgd77.c
 *
 *    Copyright (c) 2005-2008 by P. Wessel
 *    See README file for copying and redistribution conditions.
 */
 
void MGD77_Read_Header_Params (struct MGD77_CONTROL *F, struct MGD77_HEADER_PARAMS *P)
{
	/* Read the netCDF-encoded MGD77 header parameters as attributes of the data set.
	 * If orig is TRUE we will recover the original MGD77 parameters; otherwise we first
	 * look for revised parameters and fall back on the original if no revision is found. */
	
EOF
# 1. strip out the structure members (except Record_Type)
key=0
n_check=0
type="char"
last="01"
egrep -v '^#|Record_Type' mgd77_header.txt > $$.1
while read name rec item size check; do
	if [ ! $last = $rec ]; then
		echo "	/* Sequence No $rec: */" >> mgd77_functions.h
	fi
	# We need a separate read/write statement for each attribute
	pre=""				# Normally, no prefix for character arrays
	cast=""
	n_item=1
	fmt="%s"
	n=`echo $size | awk -F'*' '{print NF}'`
	if [ $n -eq 1 ]; then	# Single item
		if [ $size -eq 1 ]; then
			echo "	char	$name;" >> mgd77_functions.h
		else
			echo "	char	$name[$size];" >> mgd77_functions.h
		fi
		L=$size
		M=0
	else			# 2-D array
		L=`echo $size | awk -F'*' '{print $1}'`
		M=`echo $size | awk -F'*' '{print $2}'`
		echo "	char	$name[$L][$M];" >> mgd77_functions.h
	fi
	if [ $L -eq 1 ]; then	# Single character
		length=1
		pre="&"		# We need to take address of a single char
#		fmt="%c"
	elif [ $M -eq 0 ]; then	# Single text length given
		length="strlen (${pre}P->$name)"
	else				# 2-D text array, dim and length given, calc total size
		n_item=$L
		length=`echo $M $L | awk '{print $1*$2}'`
		cast="(char *)"
	fi
	if [ $L -eq 1 ]; then	# Special handling since these are single characters that may be \0 
		echo "	MGD77_Get_Param (F, "\"$name\"", ${cast}${pre}P->$name);" >> mgd77_functions.c
		echo "	MGD77_Put_Param (F, "\"$name\"", (size_t)$length, ${cast}${pre}P->$name);" >> $$.2
		echo "	(void) nc_del_att (F->nc_id, NC_GLOBAL, "\"${name}_REVISED\"");" >> $$.5
		# The next line gives "      Parameter_Name :Value".  This format is deliberate in that we may want to
		# use awk -F: to separate out the parameter ($1) and the value ($2). Remember Value could be a sentence with spaces!
		echo "	word[0] = P->$name;" >> $$.3
		echo "	if (F->Want_Header_Item[$key]) printf (\"%s %44s :${fmt}%c\", F->NGDC_id, \"$name\", word, EOL);" >> $$.3
		echo "	H[$key].ptr = ${cast}${pre}P->$name;" >> $$.7
	elif [ $n_item -ne 7 ]; then
		echo "	MGD77_Get_Param (F, "\"$name\"", ${cast}${pre}P->$name);" >> mgd77_functions.c
		echo "	MGD77_Put_Param (F, "\"$name\"", $length, ${cast}${pre}P->$name);" >> $$.2
		echo "	(void) nc_del_att (F->nc_id, NC_GLOBAL, "\"${name}_REVISED\"");" >> $$.5
		# The next line gives "      Parameter_Name :Value".  This format is deliberate in that we may want to
		# use awk -F: to separate out the parameter ($1) and the value ($2). Remember Value could be a sentence with spaces!
		echo "	if (F->Want_Header_Item[$key]) printf (\"%s %44s :${fmt}%c\", F->NGDC_id, \"$name\", P->$name, EOL);" >> $$.3
		echo "	H[$key].ptr = ${cast}${pre}P->$name;" >> $$.7
	else
		cast=""
		length=`echo $M | awk '{print $1-1}'`
		j=0
		while [ $j -lt $n_item ]; do
			k=$j
			j=`expr $j + 1`
			length="strlen (${pre}P->${name}[$k])"
			echo "	MGD77_Get_Param (F, "\"${name}_$j\"", ${cast}${pre}P->$name[$k]);" >> mgd77_functions.c
			echo "	MGD77_Put_Param (F, "\"${name}_$j\"", $length, ${cast}${pre}P->$name[$k]);" >> $$.2
			echo "	(void) nc_del_att (F->nc_id, NC_GLOBAL, "\"${name}_${j}_REVISED\"");" >> $$.5
			echo "	if (F->Want_Header_Item[$key]) printf (\"%s %44s :${fmt}%c\", F->NGDC_id, \"$name\", P->$name[$k], EOL);" >> $$.3
		done
		echo "	H[$key].ptr = (char *)${pre}P->$name;" >> $$.7
	fi
	if [ $check = "Y" ]; then
		echo "	\"$name\" $L $rec $item TRUE NULL" >> $$.6
	else
		echo "	\"$name\" $L $rec $item FALSE NULL" >> $$.6
	fi
	key=`expr $key + 1`
	last=$rec
done < $$.1

n_names=`cat $$.6 | wc -l | awk '{printf "%d\n", $1}'`
cat << EOF >> mgd77_functions.c
}

void MGD77_Write_Header_Params (struct MGD77_CONTROL *F, struct MGD77_HEADER_PARAMS *P)
{
	/* Write the MGD77 header parameters as attributes of the netCDF-encoded data set */
	
EOF
cat $$.2 >> mgd77_functions.c
cat << EOF >> mgd77_functions.c
}

void MGD77_Dump_Header_Params (struct MGD77_CONTROL *F, struct MGD77_HEADER_PARAMS *P)
{
	char word[2] = { '\0', '\0'}, EOL = '\n';

	/* Write all the individual MGD77 header parameters to stdout */

EOF
cat $$.3 >> mgd77_functions.c
cat << EOF >> mgd77_functions.c
}

void MGD77_Reset_Header_Params (struct MGD77_CONTROL *F)
{
	/* Remove the revised MGD77 header attributes so we return to the original values.
	 * Here we simply ignore return values since many of these are presumably unknown attributes.
	 * File is assumed to be in define mode. */
	
EOF
cat $$.5 >> mgd77_functions.c
cat << EOF >> mgd77_functions.c
	(void) nc_del_att (F->nc_id, NC_GLOBAL, "E77");
}

void MGD77_Get_Param (struct MGD77_CONTROL *F, char *name, char *value)
{	/* Get a single parameter: original if requested, otherwise check for revised value first */

	if (!F->original) {	/* Must look for revised attribute first */
		char Att[64];
		sprintf (Att, "%s_REVISED", name);	/* Revised attributes have _REVISED at the end of their names */
		if (nc_get_att_text (F->nc_id, NC_GLOBAL, Att, value) == NC_NOERR)	return;	/* Found a revised attribute */
	}
	
	/* We get here if we want the original or could not find a revised value */
	
	MGD77_nc_status (nc_get_att_text (F->nc_id, NC_GLOBAL, name, value));
}

void MGD77_Put_Param (struct MGD77_CONTROL *F, char *name, size_t length, char *value)
{	/* Place a single revised parameter: use original attribute if requested;
	 * otherwise use a revised attribute name.
	 * FUnction assumes we are in define mode. */

	if (F->original)	/* Use original attribute name */
		MGD77_nc_status (nc_put_att_text (F->nc_id, NC_GLOBAL, name, length, value));
	else {	/* Create revised attribute first */
		char Att[64];
		sprintf (Att, "%s_REVISED", name);	/* Revised attributes have _REVISED at the end of their names */
		MGD77_nc_status (nc_put_att_text (F->nc_id, NC_GLOBAL, Att, length, value));
	}
}
EOF
cat << EOF >> mgd77_functions.h
};

void MGD77_Get_Param (struct MGD77_CONTROL *F, char *name, char *value);
void MGD77_Put_Param (struct MGD77_CONTROL *F, char *name, size_t length, char *value);
void MGD77_Read_Header_Params (struct MGD77_CONTROL *F, struct MGD77_HEADER_PARAMS *P);
void MGD77_Read_Header_Params (struct MGD77_CONTROL *F, struct MGD77_HEADER_PARAMS *P);
void MGD77_Dump_Header_Params (struct MGD77_CONTROL *F, struct MGD77_HEADER_PARAMS *P);
void MGD77_Reset_Header_Params (struct MGD77_CONTROL *F);
void MGD77_Init_Ptr (struct MGD77_HEADER_LOOKUP *H, struct MGD77_HEADER_PARAMS *P);
int MGD77_Param_Key (GMT_LONG record, int item);

#define MGD77_N_HEADER_PARAMS	$n_names

extern struct MGD77_HEADER_LOOKUP MGD77_Header_Lookup[];
EOF

cat << EOF >> mgd77_functions.c
 
struct MGD77_HEADER_LOOKUP MGD77_Header_Lookup[MGD77_N_HEADER_PARAMS] = {
EOF
awk '{printf "\t{ %-46s, %3d, %2d, %2d, %5s, %s },\n", $1, $2, $3, $4, $5, $6}' $$.6 >> mgd77_functions.c
cat << EOF >> mgd77_functions.c
};

void MGD77_Init_Ptr (struct MGD77_HEADER_LOOKUP *H, struct MGD77_HEADER_PARAMS *P)
{	/* Assigns array of pointers to each idividual parameter */

EOF
cat $$.7 >> mgd77_functions.c
echo "}" >> mgd77_functions.c

rm -f $$.*
echo "mgd77netcdfhelper.sh: mgd77_functions.[ch] created"
