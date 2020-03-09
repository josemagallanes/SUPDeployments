Function Set-UpdateGroupName {
    <#
        .SYNOPSIS
        Get the properly named header for this month's patches
        .DESCRIPTION
        Formats this month's software update group name in to YYYY MM MM Format
        .EXAMPLE
        Example Output for January 2020: "2020 01 JAN"
    #>
    param (
        [datetime]$day
    )
    $month = $day.ToString("MMMM").ToUpper().Substring(0,3)
    $month_number = $day.Month.ToString()
    if ($month_number.length -eq 1) {
        $month_number = "0" + $month_number # single digit months (ie Jan = 1)
    }
    else {
        $month_number = $day.Month.ToString()
    }
    $softwareUpdateName = $day.Year.ToString() + " " + `
                          $month_number + " " + $month
    return $softwareUpdateName
}