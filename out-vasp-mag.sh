#!/bin/bash

# VASP Analysis Script - Improved Version
# Analyzes VASP calculations and extracts energy, magnetization, and other properties

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Configuration
readonly SCRIPT_DIR="${SCRIPT_DIR:-$HOME/Skrypty}"
readonly outfile1="all-energy.txt"
readonly temp4_mag="all-mag-temp4.txt"
readonly outfile1_sub_mag="all-mag.txt"
readonly outfile2_magnetization="all-magnetization.txt"
readonly outfile3_magnetization_ncol="all-magnetization_ncol.txt"

# Global variables
curdir=""

# Utility functions
log_error() {
    echo "Error: $*" >&2
}

log_warning() {
    echo "Warning: $*" >&2
}

# Validation functions
validate_environment() {
    local required_tools=("grep" "awk" "sed" "cut" "sort" "head" "tail")
    
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            log_error "Required tool '$tool' not found"
            exit 1
        fi
    done
    
    if [[ ! -d "$(pwd)" ]]; then
        log_error "Current directory not accessible"
        exit 1
    fi
}

# File operations
cleanup_files() {
    rm -f TEMP* "$outfile1" "$outfile1_sub_mag" "$outfile2_magnetization" "$outfile3_magnetization_ncol"
}

initialize_output_files() {
    {
        printf 'Name                                                                  Result                     Cycles    Time           Symm   KPOINTS          TOTEN/eV            Volume    '
        echo 'Name                                                                  Magnetizations_of_ions...'
    } >> "$outfile1"
    
    echo 'Name                                                                  Magnetizations_of_ions...' >> "$outfile1_sub_mag"
}

# Directory listing and sorting
create_directory_list() {
    if ! ls --color=no -h > list 2>/dev/null; then
        log_error "Failed to create directory list"
        exit 1
    fi
}

# Queue and job management
extract_queue_id() {
    local dir="$1"
    local queue_id=""
    
    if ls "$dir"/slurm* >/dev/null 2>&1; then
        queue_id=$(echo "$dir"/*.out | rev | cut -d- -f1 | rev | cut -d. -f1)
    elif [[ -e "$dir"/*.out ]]; then
        queue_id=$(grep 'SLURM_JOB_ID' "$dir"/*.out 2>/dev/null | cut -d' ' -f3 | head -1)
    elif ls "$dir" 2>/dev/null | grep -q -E '^[0-9]+$'; then
        queue_id=$(ls "$dir" 2>/dev/null | grep -E '^[0-9]+$')
    else
        queue_id='unknown'
    fi
    
    echo "${queue_id:-unknown}"
}

# File processing
process_structure_files() {
    local dir="$1"
    
    rm -f "$dir"/*.vasp
    
    # Copy CONTCAR if exists
    if [[ -e "$dir/CONTCAR" ]]; then
        echo "${dir##*/}"
        cp "$dir/CONTCAR" "$dir/${dir##*/}-CONTCAR.vasp"
    fi
    
    # Copy POSCAR if exists
    if [[ -e "$dir/POSCAR" ]]; then
        cp "$dir/POSCAR" "$dir/${dir##*/}-POSCAR.vasp"
    fi
}

# Error detection
check_calculation_errors() {
    local dir="$1"
    local error_found=""
    
    if ls "$dir"/slurm* >/dev/null 2>&1; then
        if grep -E -q -i 'warning|error|incompat' "$dir"/*out 2>/dev/null; then
            if grep -q "stress and forces are not correct" "$dir"/*out 2>/dev/null; then
                error_found=" "
            else
                local words=('warning' 'error' 'incompat')
                for w in "${words[@]}"; do
                    if grep -q -i "$w" "$dir"/*out 2>/dev/null; then
                        error_found="$w"
                        break
                    fi
                done
            fi
        else
            error_found=" "
        fi
    else
        error_found="no_stdout_"
    fi
    
    printf "%-9s" "${error_found// /_}"
}

# Job status checking
check_job_status() {
    local dir="$1"
    local queue_id="$2"
    
    if squeue -u matdom 2>/dev/null | grep -q "$queue_id"; then
        printf "%-18s" "$queue_id"
        if [[ ! -e "$dir"/*.out ]]; then
            printf "%-18s" 'In_queue...'
            echo
            return 1  # Skip further processing
        fi
    elif grep -q 'Total CPU time used' "$dir/OUTCAR" 2>/dev/null; then
        printf "%-9s" "Finished_"
        
        # Check optimization status
        local nelm nelm_done
        nelm=$(grep -a -i 'nelm ' "$dir/OUTCAR" 2>/dev/null | awk -F ' ' '{print $3}' | sed 's/[^0-9]*//g')
        nelm_done=$(grep -a 'D.*:' "$dir/OSZICAR" 2>/dev/null | tail -1 | awk -F ' ' '{print $2}' | sed 's/[^0-9]*//g')
        
        if [[ -n "$nelm" && -n "$nelm_done" ]] && ! (( nelm > nelm_done )); then
            printf "%-9s" 'NELM_lim'
        elif grep -q 'reached required accuracy' "$dir/OUTCAR" 2>/dev/null; then
            printf "%-9s" 'Opt'
        elif grep -q 'NSW    =      0' "$dir/OUTCAR" 2>/dev/null; then
            printf "%-9s" 'S-Point'
        else
            printf "%-9s" 'Not-opt'
        fi
    else
        printf "%-18s" 'Not_finished'
    fi
    
    return 0
}

# Calculation metrics
extract_cycles() {
    local dir="$1"
    local cycles=0
    
    if grep -q 'F= ' "$dir/OSZICAR" 2>/dev/null; then
        cycles=$(grep -a 'F= ' "$dir/OSZICAR" 2>/dev/null | tail -1 | cut -c 1-5 | tr -d '\n' | tr -d ' ')
    fi
    
    printf "%-10s" "${cycles:-0}"
}

extract_timing() {
    local dir="$1"
    local queue_id="$2"
    
    if grep -q 'Total CPU time used' "$dir/OUTCAR" 2>/dev/null; then
        local seconds minutes hours remainder
        seconds=$(grep -a 'Elapsed time' "$dir/OUTCAR" 2>/dev/null | tail -1 | cut -c 45-58 | tr -d '\n' | tr -d ' ' | cut -d '.' -f 1)
        
        if [[ -n "$seconds" && "$seconds" =~ ^[0-9]+$ ]]; then
            minutes=$((seconds / 60))
            if (( minutes > 60 )); then
                hours=$((minutes / 60))
                minutes=$((minutes - hours * 60))
            else
                hours=0
            fi
            remainder=$((seconds - hours * 3600 - minutes * 60))
            printf "%-15s" "${hours}h_${minutes}min_${remainder}s"
        else
            printf "%-15s" "time_parse_error"
        fi
    elif squeue -u matdom 2>/dev/null | grep -q "$queue_id"; then
        printf "%-15s" "calculating..."
    else
        printf "%-15s" "time_limit_met"
    fi
}

extract_symmetry() {
    local dir="$1"
    local symm=""
    
    if grep -q 'point group associated with its full space group' "$dir/OUTCAR" 2>/dev/null; then
        symm=$(grep -a -i 'point group associated with its full space group' "$dir/OUTCAR" 2>/dev/null | tr -d '.' | awk '{print $NF}' | tail -1)
    elif grep -q 'All symmetrisations will be switched off' "$dir/OUTCAR" 2>/dev/null; then
        symm='C_1'
    else
        symm=$(grep -a -i 'static configuration has the point symmetry' "$dir/OUTCAR" 2>/dev/null | tr -d '.' | awk '{print $NF}' | tail -1)
    fi
    
    printf "%-7s" "${symm:-unknown}"
}

extract_kpoints() {
    local dir="$1"
    local kpoints=""
    
    if [[ -e "$dir/KPOINTS" ]]; then
        if grep -q 'Auto' "$dir/KPOINTS" 2>/dev/null; then
            kpoints=$(sed -n '4p' "$dir/KPOINTS" 2>/dev/null | sed -e 's/ /_/g' | tr -d '\n' | tr -d '\r')
            printf "%-17s" "${kpoints:-Auto}"
        else
            printf "%-17s" 'Explicit_kpoints'
        fi
    elif grep -q -i 'kspacing' "$dir/INCAR" 2>/dev/null; then
        kpoints=$(grep -a -i 'kspacing' "$dir/INCAR" 2>/dev/null | awk -F ' ' '{print $3}' | tr -d '\n' | tr -d '\r')
        printf "%-17s" "spacing=${kpoints:-unknown}"
    else
        kpoints=$(grep -a 'generate k-points' "$dir"/*.out 2>/dev/null | cut -c 25-40 | sed -e 's/ /_/g' | tr -d '\n' | tr -d '\r')
        printf "%-17s" "${kpoints:-unknown}"
    fi
}

extract_total_energy() {
    local dir="$1"
    
    if grep -q -i 'toten' "$dir/OUTCAR" 2>/dev/null; then
        local toten
        toten=$(grep -a 'TOTEN  ' "$dir/OUTCAR" 2>/dev/null | tail -1 | cut -c 30-45 | tr -d '\n' | tr -d ' ' | tr -d 'A-Za-z*')
        printf "%-20s" "${toten:-error}"
    elif grep -q -i 'fail' "$dir"/*out 2>/dev/null; then
        grep -a -i -h 'fail' "$dir"/*out 2>/dev/null | tail -1 | sed -e 's/ /_/g' | tr -d '\n' >> "$outfile1"
    elif grep -q -i 'error' "$dir"/*out 2>/dev/null; then
        grep -a -i -h 'error' "$dir"/*out 2>/dev/null | tail -1 | sed -e 's/ /_/g' | tr -d '\n' >> "$outfile1"
    fi
}

extract_volume() {
    local dir="$1"
    local volume
    
    volume=$(grep -a 'volume of cell :' "$dir/OUTCAR" 2>/dev/null | cut -c 20-31 | tail -1 | tr -d '\n' | tr -d ' ')
    printf "%-10s" "${volume:-unknown}"
}

check_primitive_cell() {
    local dir="$1"
    
    if grep -q 'primitive cells build up' "$dir/OUTCAR" 2>/dev/null; then
        printf "%-50s primitive_cell_found\n" "$dir" >> TEMP3
    fi
}

# Magnetization processing functions
create_xsf_header() {
    local dir="$1"
    local at_types at_count at_no
    
    rm -f "$dir"/tmp_*
    {
        echo 'CRYSTAL'
        echo 'PRIMVEC'
        sed -n '3,5p' "$dir/CONTCAR" 2>/dev/null
        echo 'PRIMCOORD'
    } > "$dir/CONTCAR.xsf"
    
    sed -n '3,5p' "$dir/CONTCAR" 2>/dev/null > "$dir/tmp_cell"
    
    at_types=$(sed -n 6p "$dir/CONTCAR" 2>/dev/null)
    at_count=$(sed -n 7p "$dir/CONTCAR" 2>/dev/null)
    at_no=$(sed -n 7p "$dir/CONTCAR" 2>/dev/null | awk '{for(i=1;i<=NF;i++) t+=$i; print t; t=0}')
    
    echo "$at_no 1" >> "$dir/CONTCAR.xsf"
    
    # Create atom type list
    local counter=0
    for p in $at_count; do
        counter=$((counter + 1))
        local at
        at=$(echo "$at_types" | cut -d ' ' -f "$counter")
        for ((l=1; l<=p; l++)); do
            printf "%-5s\n" "$at" >> "$dir/tmp_at"
        done
    done
    
    # Handle fractional coordinates
    if grep -q -i 'sel' "$dir/CONTCAR" 2>/dev/null; then
        sed -n '10,$p' "$dir/CONTCAR" 2>/dev/null | head -n "$at_no" > "$dir/tmp_frac_sel"
        awk 'NF{NF-=3};1' < "$dir/tmp_frac_sel" > "$dir/tmp_frac" 2>/dev/null || true
    else
        sed -n '9,$p' "$dir/CONTCAR" 2>/dev/null | head -n "$at_no" > "$dir/tmp_frac"
    fi
    
    echo "$at_no"
}

process_collinear_magnetization() {
    local dir="$1"
    local temp_file="TEMP"
    
    if grep -q 'General timing and accounting informations for this job' "$dir/OUTCAR" 2>/dev/null; then
        grep -a -B 800 'General timing and accounting informations for this job' "$dir/OUTCAR" > "$temp_file"
    elif grep -q -i 'magnetization (x)' "$dir/OUTCAR" 2>/dev/null; then
        tail -n 1000 "$dir/OUTCAR" > "$temp_file"
    else
        echo >> "$outfile1"
        return 1
    fi
    
    printf "%-70s " "$dir" >> "$temp4_mag"
    printf "%-70s " "$dir" >> "$outfile1_sub_mag"
    printf "%s\n" "$dir" >> "$outfile2_magnetization"
    
    local temp2_file="TEMP2"
    if grep -q 'tot       ' "$temp_file" 2>/dev/null; then
        sed -n "/magnetization (x)/, /tot      /{p; /tot      /q}" "$temp_file" | sed '1,2d' > "$temp2_file"
        cat "$temp2_file" >> "$outfile2_magnetization"
        echo >> "$outfile2_magnetization"
        sed -i '1,2d' "$temp2_file"
        head -n -2 "$temp2_file" > "$temp_file"
        mv "$temp_file" "$temp2_file"
    else
        grep -a -A4 "magnetization (x)" "$temp_file" 2>/dev/null | tail -1 > "$temp2_file"
    fi
    
    # Create XSF structure
    local at_no
    at_no=$(create_xsf_header "$dir")
    
    # Process magnetization data
    local lastline number
    lastline=$(tail -1 "$temp2_file" 2>/dev/null | head -1)
    number=$(echo "$lastline" | cut -f 1 -d ' ')
    
    if [[ -z "$number" ]]; then
        printf "no_magnetization_in_the_OUTCAR" >> "$outfile1_sub_mag"
    else
        for ((i=number; i>=1; i--)); do
            local lastline2 magnetization mag_abs
            lastline2=$(tail -n "$i" "$temp2_file" 2>/dev/null | head -1)
            
            if grep -q 'd       f       tot' "$dir/OUTCAR" 2>/dev/null; then
                magnetization=$(echo "$lastline2" | cut -f 6 -d ' ' | tr -d '\n')
            else
                magnetization=$(echo "$lastline2" | cut -f 5 -d ' ' | tr -d '\n')
            fi
            
            LANG=C printf "%7.3f" "$magnetization" >> "$temp4_mag"
            LANG=C printf "%7.3f" "$magnetization" >> "$outfile1_sub_mag"
            
            mag_abs=${magnetization#-}  # Absolute value
            if [[ -n "$magnetization" ]] && (( $(echo "0.2 < $mag_abs" | bc -l 2>/dev/null || echo 0) )); then
                LANG=C printf "%7.3f" "$magnetization" >> "$dir/tmp_mag_x_row"
            else
                LANG=C printf "%7.3f" 0 >> "$dir/tmp_mag_x_row"
            fi
        done
        
        # Create XSF file with magnetization vectors
        if [[ -x "$SCRIPT_DIR/awk-matrix/matrix-mult.awk" ]]; then
            "$SCRIPT_DIR/awk-matrix/matrix-mult.awk" "$dir/tmp_frac" "$dir/tmp_cell" > "$dir/tmp_xyz_raw" 2>/dev/null || true
            awk '{printf "%.10f %.10f %.10f \n", $1, $2, $3}' "$dir/tmp_xyz_raw" > "$dir/tmp_xyz" 2>/dev/null || true
            
            if [[ -x "$SCRIPT_DIR/awk-matrix/matrix-transpose.awk" ]]; then
                "$SCRIPT_DIR/awk-matrix/matrix-transpose.awk" "$dir/tmp_mag_x_row" > "$dir/tmp_mag_x" 2>/dev/null || true
                sed -e 's/[0-9]\+/0/g' "$dir/tmp_mag_x" > "$dir/tmp_mag_y" 2>/dev/null || true
                cp "$dir/tmp_mag_y" "$dir/tmp_mag_z" 2>/dev/null || true
                paste "$dir/tmp_at" "$dir/tmp_xyz" "$dir/tmp_mag_y" "$dir/tmp_mag_z" "$dir/tmp_mag_x" >> "$dir/CONTCAR.xsf" 2>/dev/null || true
                sed -i 's/\t/ /g; s/ -/-/g' "$dir/CONTCAR.xsf" 2>/dev/null || true
            fi
        else
            log_warning "Matrix multiplication script not found at $SCRIPT_DIR/awk-matrix/matrix-mult.awk"
        fi
    fi
    
    rm -f "$temp2_file"
    echo >> "$outfile1_sub_mag"
    cat "$temp4_mag" >> "$outfile1"
    rm -f "$temp4_mag"
    
    return 0
}

process_noncollinear_magnetization() {
    local dir="$1"
    
    rm -f "$dir"/TEMP_ncol_*
    echo 'non-collinear'
    
    if ! grep -q 'General timing and accounting informations for this job' "$dir/OUTCAR" 2>/dev/null; then
        return 1
    fi
    
    printf "%-70s " "$dir" >> "$outfile1_sub_mag"
    printf "%-70s " "$dir" >> "$temp4_mag"
    
    local at_no
    at_no=$(create_xsf_header "$dir")
    
    # Process x, y, z components
    for k in {x,y,z}; do
        printf "%-70s " "$dir" >> "$outfile3_magnetization_ncol"
        printf "%-2s" "$k" >> "$outfile3_magnetization_ncol"
        
        local temp_file="TEMP"
        grep -a -B 800 'General timing and accounting informations for this job' "$dir/OUTCAR" > "$temp_file"
        printf "%s\n" "$dir" >> "$outfile2_magnetization"
        
        local temp2_file="TEMP2"
        if grep -q -a 'tot       ' "$temp_file" 2>/dev/null; then
            sed -n "/magnetization ($k)/, /tot      /{p; /tot      /q}" "$temp_file" | sed '1,2d' > "$temp2_file"
            cat "$temp2_file" >> "$outfile2_magnetization"
            echo >> "$outfile2_magnetization"
            sed -i '1,2d' "$temp2_file"
            head -n -2 "$temp2_file" > "$temp_file"
            mv "$temp_file" "$temp2_file"
        else
            grep -A4 "magnetization ($k)" "$temp_file" 2>/dev/null | tail -1 > "$temp2_file"
        fi
        
        local lastline number
        lastline=$(tail -1 "$temp2_file" 2>/dev/null | head -1)
        number=$(echo "$lastline" | cut -f 1 -d ' ')
        
        for ((i=number; i>=1; i--)); do
            local lastline2 atom magnetization
            lastline2=$(tail -n "$i" "$temp2_file" 2>/dev/null | head -1)
            atom=$(echo "$lastline2" | cut -f 1 -d ' ')
            
            if grep -q 'd       f       tot' "$dir/OUTCAR" 2>/dev/null; then
                magnetization=$(echo "$lastline2" | cut -f 6 -d ' ' | tr -d '\n')
            else
                magnetization=$(echo "$lastline2" | cut -f 5 -d ' ' | tr -d '\n')
            fi
            
            LANG=C printf "%7.3f" "$magnetization" >> "$outfile3_magnetization_ncol"
            LANG=C printf "%7.3f" "$magnetization" >> "$dir/TEMP_ncol_$atom"
            LANG=C printf "%7.3f\n" "$magnetization" >> "$dir/tmp_mag_$k"
            
            # Store rough magnetization (threshold 0.20)
            if [[ -n "$magnetization" ]] && (( $(echo "0.20 < ${magnetization#-}" | bc -l 2>/dev/null || echo 0) )); then
                LANG=C printf "%7.3f\n" "$magnetization" >> "$dir/tmp_mag_rough_$k"
            else
                LANG=C printf "%7.3f\n" 0 >> "$dir/tmp_mag_rough_$k"
            fi
        done
        
        rm -f "$temp2_file"
        echo >> "$outfile3_magnetization_ncol"
    done
    
    # Create XSF files
    if [[ -x "$SCRIPT_DIR/awk-matrix/matrix-mult.awk" ]]; then
        "$SCRIPT_DIR/awk-matrix/matrix-mult.awk" "$dir/tmp_frac" "$dir/tmp_cell" > "$dir/tmp_xyz_raw" 2>/dev/null || true
        awk '{printf "%.10f %.10f %.10f \n", $1, $2, $3}' "$dir/tmp_xyz_raw" > "$dir/tmp_xyz" 2>/dev/null || true
        
        # Create both rough and detailed XSF files
        paste "$dir/tmp_at" "$dir/tmp_xyz" "$dir/tmp_mag_rough_x" "$dir/tmp_mag_rough_y" "$dir/tmp_mag_rough_z" >> "$dir/CONTCAR_rough.xsf" 2>/dev/null || true
        paste "$dir/tmp_at" "$dir/tmp_xyz" "$dir/tmp_mag_x" "$dir/tmp_mag_y" "$dir/tmp_mag_z" >> "$dir/CONTCAR.xsf" 2>/dev/null || true
        
        # Clean up tab formatting
        tr '\t' ' ' < "$dir/CONTCAR_rough.xsf" > "$dir/CONTCAR_rough_clean.xsf" 2>/dev/null && mv "$dir/CONTCAR_rough_clean.xsf" "$dir/CONTCAR_rough.xsf"
        tr '\t' ' ' < "$dir/CONTCAR.xsf" > "$dir/CONTCAR_clean.xsf" 2>/dev/null && mv "$dir/CONTCAR_clean.xsf" "$dir/CONTCAR.xsf"
    fi
    
    # Handle SAXIS rotation if Python script exists
    if grep -i 'SAXIS' "$dir/INCAR" > "$dir/temp_saxis" 2>/dev/null; then
        if [[ -x "$HOME/Skrypty/noncol_rot_saxis.py" ]]; then
            (cd "$dir" && python "$HOME/Skrypty/noncol_rot_saxis.py" 2>/dev/null || true)
            if [[ -e "$dir/temp_xsf" ]]; then
                sed -n '1,7p' "$dir/CONTCAR.xsf" > "$dir/CONTCAR_saxis.xsf"
                cat "$dir/temp_xsf" >> "$dir/CONTCAR_saxis.xsf"
                rm -f "$dir/temp_saxis" "$dir/temp_xsf"
            fi
        fi
    fi
    
    # Calculate magnetization magnitudes
    local number
    number=$(echo "$lastline" | cut -f 1 -d ' ')
    for ((atom=1; atom<=number; atom++)); do
        if [[ -e "$dir/TEMP_ncol_$atom" ]]; then
            local sq_mag
            sq_mag=$(awk '{if ($1+$2+$3 > 0) {s += ($1)^2+($2)^2+($3)^2; t=s^0.5} else {s += ($1)^2+($2)^2+($3)^2; t=-s^0.5}}; END{print (t+0)/NR}' "$dir/TEMP_ncol_$atom" 2>/dev/null)
            LANG=C printf "%7.3f" "${sq_mag:-0}" >> "$temp4_mag"
            LANG=C printf "%7.3f" "${sq_mag:-0}" >> "$outfile1_sub_mag"
        fi
    done
    
    cat "$temp4_mag" >> "$outfile1"
    rm -f "$temp4_mag"
    echo >> "$outfile1_sub_mag"
    echo >> "$outfile3_magnetization_ncol"
    
    return 0
}

process_magnetization() {
    local dir="$1"
    
    # Skip backup directories
    if [[ "$dir" == *"backup"* ]]; then
        return 0
    fi
    
    local ispin_tag ncol_tag
    ispin_tag=$(grep -a -i 'ISPIN' "$dir/OUTCAR" 2>/dev/null | cut -c 1-19 | tr -d ' ' | tr -d 'ISPIN=' | head -1)
    ncol_tag=$(grep -a -i 'LNONCOLLINEAR' "$dir/OUTCAR" 2>/dev/null | cut -c 1-26 | tr -d ' ' | tr -d 'LNONCOLLINEAR=' | head -1)
    
    if [[ "$ispin_tag" = "1" && "$ncol_tag" = "F" ]]; then
        printf "%-70s " "$dir" >> "$outfile1"
        printf " ISPIN=1" >> "$outfile1"
        printf "%-70s " "$dir" >> "$outfile1_sub_mag"
        echo " ISPIN=1" >> "$outfile1_sub_mag"
    elif [[ "$ispin_tag" = "2" && "$ncol_tag" = "F" ]]; then
        process_collinear_magnetization "$dir"
    elif [[ "$ncol_tag" = "T" ]]; then
        process_noncollinear_magnetization "$dir"
    fi
}

# Main directory processing
process_directory() {
    local dir="$1"
    
    # Skip backup directories with message
    if [[ "$dir" == *"backup"* ]]; then
        printf 'omit %s\n' "$dir"
        return 0
    fi
    
    # Check if OUTCAR exists
    if [[ ! -e "$dir/OUTCAR" ]]; then
        # Check for queued job
        if [[ -e "$dir/POSCAR" ]]; then
            printf "%-70s" "$dir" >> "$outfile1"
            printf "%-17s" 'Job_queued_or_not_started' >> "$outfile1"
        fi
        echo >> "$outfile1"
        return 0
    fi
    
    # Extract queue ID
    local queue_id
    queue_id=$(extract_queue_id "$dir")
    
    # Process structure files
    process_structure_files "$dir"
    
    # Start building output line
    printf "%-70s " "$dir" >> "$outfile1"
    
    # Check for errors
    check_calculation_errors "$dir" >> "$outfile1"
    
    # Check job status
    if ! check_job_status "$dir" "$queue_id" >> "$outfile1"; then
        return 0  # Job still in queue, skip further processing
    fi
    
    # Extract calculation metrics
    extract_cycles "$dir" >> "$outfile1"
    extract_timing "$dir" "$queue_id" >> "$outfile1"
    extract_symmetry "$dir" >> "$outfile1"
    extract_kpoints "$dir" >> "$outfile1"
    extract_total_energy "$dir" >> "$outfile1"
    extract_volume "$dir" >> "$outfile1"
    
    # Check for primitive cell
    check_primitive_cell "$dir"
    
    # Clean up XSF files
    rm -f "$dir"/CONTCAR*xsf 2>/dev/null || true
    
    # Process magnetization
    process_magnetization "$dir"
    
    # Clean up temporary files for this directory
    rm -f "$dir"/TEMP_ncol_* "$dir"/tmp_* 2>/dev/null || true
    
    echo >> "$outfile1"
}

# Main execution function
main() {
    echo "Starting VASP analysis script..."
    
    # Validate environment
    validate_environment
    
    # Store current directory
    curdir=$(pwd)
    
    # Clean up old files
    cleanup_files
    
    # Initialize output files
    initialize_output_files
    
    # Create directory list
    create_directory_list
    
    echo "Processing directories..."
    
    # Process each directory
    local processed_count=0
    while read -r dir; do
        if [[ -d "$dir" ]]; then
            process_directory "$dir"
            processed_count=$((processed_count + 1))
            
            # Progress indicator
            if (( processed_count % 10 == 0 )); then
                echo "Processed $processed_count directories..."
            fi
        fi
    done < list
    
    # Clean up directory list
    rm -f list
    
    # Finalize output
    echo >> "$outfile1"
    if [[ -e "$outfile1_sub_mag" ]]; then
        cat "$outfile1_sub_mag" >> "$outfile1"
    fi
    
    # Add supercell information if found
    if [[ -e TEMP3 ]]; then
        echo >> "$outfile1"
        printf "supercells...\n" >> "$outfile1"
        cat TEMP3 >> "$outfile1"
        rm -f TEMP3
    fi
    
    # Final cleanup
    rm -f "$temp4_mag" "$outfile1_sub_mag" TEMP* 2>/dev/null || true
    
    echo "Analysis complete. Results written to:"
    echo "  - Main output: $outfile1"
    echo "  - Magnetization data: $outfile2_magnetization"
    echo "  - Non-collinear magnetization: $outfile3_magnetization_ncol"
    
    # Display summary statistics
    if [[ -e "$outfile1" ]]; then
        local total_dirs finished_dirs error_dirs
        total_dirs=$(grep -c "^[^[:space:]]" "$outfile1" 2>/dev/null || echo 0)
        finished_dirs=$(grep -c "Finished_" "$outfile1" 2>/dev/null || echo 0)
        error_dirs=$(grep -c -E "error|warning|fail" "$outfile1" 2>/dev/null || echo 0)
        
        echo
        echo "Summary:"
        echo "  Total directories processed: $total_dirs"
        echo "  Finished calculations: $finished_dirs"
        echo "  Calculations with errors/warnings: $error_dirs"
    fi
}

# Error handling
cleanup_on_exit() {
    local exit_code=$?
    if (( exit_code != 0 )); then
        log_error "Script terminated unexpectedly with exit code $exit_code"
        echo "Cleaning up temporary files..."
        rm -f TEMP* list 2>/dev/null || true
    fi
    exit $exit_code
}

# Set up signal handlers
trap cleanup_on_exit EXIT
trap 'echo "Script interrupted by user"; exit 130' INT TERM

# Help function
show_help() {
    cat << EOF
VASP Analysis Script - Improved Version

This script analyzes VASP calculations and extracts information about:
- Energy and optimization status
- Timing and computational details  
- Symmetry and k-point information
- Magnetization data (collinear and non-collinear)
- Volume and structural information

USAGE:
    $0 [OPTIONS]

OPTIONS:
    -h, --help     Show this help message
    --script-dir   Set custom script directory (default: \$HOME/Skrypty)

REQUIREMENTS:
    - VASP calculation directories with OUTCAR files
    - Standard Unix tools: grep, awk, sed, cut, sort
    - Optional: matrix manipulation scripts in SCRIPT_DIR/awk-matrix/
    - Optional: Python script for SAXIS rotation (noncol_rot_saxis.py)

OUTPUT FILES:
    - all-energy.txt: Main output with all analysis results
    - all-magnetization.txt: Detailed magnetization data
    - all-magnetization_ncol.txt: Non-collinear magnetization data
    - Individual .xsf files: Visualization files with magnetic vectors

EXAMPLES:
    $0                                    # Run with default settings
    $0 --script-dir /custom/path          # Use custom script directory

For more information, see the documentation or contact the maintainer.
EOF
}

# Command line argument parsing
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            --script-dir)
                if [[ -n "$2" && ! "$2" =~ ^- ]]; then
                    SCRIPT_DIR="$2"
                    shift 2
                else
                    log_error "Option --script-dir requires a directory path"
                    exit 1
                fi
                ;;
            *)
                log_error "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Parse command line arguments
    parse_arguments "$@"
    
    # Check if bc is available for floating point comparisons
    if ! command -v bc >/dev/null 2>&1; then
        log_warning "bc (calculator) not found. Some magnetization threshold checks may not work properly."
    fi
    
    # Run main function
    main
fi
