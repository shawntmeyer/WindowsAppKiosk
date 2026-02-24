Function Test-UrlCoveredByFilter {
    <#
    .SYNOPSIS
        Tests if a URL is covered by any filter patterns in a list of allowed URLs.
    
    .DESCRIPTION
        This function checks if a given URL is covered by any filter patterns using Edge URL filter format rules.
        It supports various pattern matching rules including exact matches, wildcards, hostname patterns,
        subdomain patterns, full URL patterns with paths, and general wildcard patterns.
        
        Reference: https://learn.microsoft.com/en-us/DeployEdge/edge-learnmmore-url-list-filter%20format
    
    .PARAMETER Url
        The URL to test against the filter patterns.
    
    .PARAMETER AllowedUrls
        An array of URL patterns to match against.
    
    .EXAMPLE
        $isCovered = Test-UrlCoveredByFilter -Url "https://www.contoso.com/page" -AllowedUrls @("contoso.com", "*.fabrikam.com")
    
    .OUTPUTS
        System.Boolean - Returns $true if the URL is covered by any filter pattern, $false otherwise.
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]
        [string]$Url,
        
        [Parameter(Mandatory = $true)]
        [string[]]$AllowedUrls
    )

    Process {
        $UrlCovered = $false
        
        foreach ($filterPattern in $AllowedUrls) {
            # Skip if already matched
            if ($UrlCovered) { break }
            
            try {
                # Rule 1: Exact match
                if ($Url -eq $filterPattern) {
                    $UrlCovered = $true
                    Write-Verbose "URL '$Url' exactly matches filter '$filterPattern'"
                    break
                }
                
                # Rule 2: Wildcard 'file://*', 'ms-avd://*', etc. - matches any URL with that scheme
                if ($filterPattern -match '^([a-z0-9\-]+)://\*$') {
                    $scheme = $matches[1]
                    if ($Url -like "${scheme}://*") {
                        $UrlCovered = $true
                        Write-Verbose "URL '$Url' is covered by scheme wildcard '$filterPattern'"
                        break
                    }
                }
                
                # Rule 3: Simple hostname (e.g., 'contoso.com') - matches the domain and ALL subdomains
                # Per Edge docs: contoso.com matches www.contoso.com, internal.contoso.com, etc.
                elseif ($filterPattern -notmatch '://' -and $filterPattern -notmatch '^\.') {
                    try {
                        $uri = [System.Uri]$Url
                        $filterDomain = $filterPattern.TrimEnd('/*')
                        # Matches exact domain OR any subdomain
                        if ($uri.Host -eq $filterDomain -or $uri.Host -like "*.$filterDomain") {
                            $UrlCovered = $true
                            Write-Verbose "URL '$Url' is covered by hostname filter '$filterPattern' (includes subdomains)"
                            break
                        }
                    } catch { }
                }
                
                # Rule 4: Hostname with leading dot (e.g., '.contoso.com') - matches ONLY subdomains, not root
                elseif ($filterPattern -match '^\.' -and $filterPattern -notmatch '://') {
                    try {
                        $uri = [System.Uri]$Url
                        $filterDomain = $filterPattern.Substring(1).TrimEnd('/*')
                        # Matches only subdomains, not the root domain
                        if ($uri.Host -like "*.$filterDomain") {
                            $UrlCovered = $true
                            Write-Verbose "URL '$Url' is covered by subdomain-only filter '$filterPattern'"
                            break
                        }
                    } catch { }
                }
                
                # Rule 5: Full URL with scheme (e.g., 'https://contoso.com') - matches that scheme + domain + subdomains
                elseif ($filterPattern -match '^([a-z0-9\-]+)://([^/\*]+)(.*)$') {
                    try {
                        $uri = [System.Uri]$Url
                        $filterScheme = $matches[1]
                        $filterHost = $matches[2]
                        $filterPath = $matches[3]
                        
                        # Scheme must match
                        if ($uri.Scheme -ne $filterScheme) { continue }
                        
                        # Host matching: contoso.com matches contoso.com and *.contoso.com
                        $hostMatches = $uri.Host -eq $filterHost -or $uri.Host -like "*.$filterHost"
                        if (-not $hostMatches) { continue }
                        
                        # Path matching
                        if ($filterPath) {
                            if ($filterPath -eq '/*' -or $filterPath -eq '*') {
                                # Wildcard path matches anything
                                $UrlCovered = $true
                            } elseif ($filterPath.Contains('*')) {
                                # Wildcard in path
                                $pathPattern = '^' + [regex]::Escape($filterPath).Replace('\*', '.*') + '$'
                                if ($uri.PathAndQuery -match $pathPattern) {
                                    $UrlCovered = $true
                                }
                            } else {
                                # Specific path
                                if ($uri.PathAndQuery -like "$filterPath*") {
                                    $UrlCovered = $true
                                }
                            }
                        } else {
                            # No path specified, matches any path
                            $UrlCovered = $true
                        }
                        
                        if ($UrlCovered) {
                            Write-Verbose "URL '$Url' is covered by full URL filter '$filterPattern'"
                            break
                        }
                    } catch { }
                }
                
                # Rule 6: Wildcard patterns with * in host (e.g., 'https://*.contoso.com')
                elseif ($filterPattern.Contains('*')) {
                    $pattern = '^' + [regex]::Escape($filterPattern).Replace('\*', '.*') + '$'
                    if ($Url -match $pattern) {
                        $UrlCovered = $true
                        Write-Verbose "URL '$Url' is covered by wildcard pattern '$filterPattern'"
                        break
                    }
                }
            }
            catch {
                # If any parsing fails, skip this pattern
                Write-Verbose "Failed to match URL against pattern '$filterPattern': $_"
                continue
            }
        }
        
        return $UrlCovered
    }
}
