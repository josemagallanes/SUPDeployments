Function Get-PatchTuesday {
<#
    .SYNOPSIS
    Get the DateTime for Microsoft's Patch Tuesday.
    .DESCRIPTION
    When run, finds the second Tuesday of the current month.
#>

    $todays_date = Get-Date # Gives us the current month for
    $traversal_date = Get-Date -Date ($todays_date.Month.ToString() + '-01-' + `
        $todays_date.Year.ToString())

    #For use when the first day of the week falls on Tuesday
    if ($traversal_date.DayOfWeek -eq 'Tuesday') {
        $tuesday_i = 1;
    } else {
        $tuesday_i = 0;
    } 

    while ($tuesday_i -ne 2) {
        $traversal_date = $traversal_date.addDays(1)
        if ($traversal_date.DayOfWeek -eq 'Tuesday') {
            $tuesday_i = $tuesday_i + 1
        }
    }
    $traversal_date #Returned value
}
Get-PatchTuesday