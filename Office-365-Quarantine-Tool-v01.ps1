<# 
.DESCRIPTION
A simple Office 365 quarantine viewer. I find the web interface to be super slow and buggy and as I use it several times a week I thought I'd put some time in to
creating a PowerShell implementation. Also this tool will allow you to wildcard search the Subject, Sender and Direction fields; the web interface doesn't give you that flexibility.
Unfortunately Microsoft doesn't make it easy to filter by recipient without first specifying the -Identity. Maybe I'll get round to doing that later.
You will be prompted for your Office 365 credentials as soon as you double click the .exe. The appropriate modules will load if the credentials and permissions are correct.
.NOTES
Author: Mikail Tunç
Web: https://emtunc.org/blog/
v01 - 31-05-2016: 	Initial version
#>

#region Control Helper Functions
function Load-ComboBox 
{
<#
	.SYNOPSIS
		This functions helps you load items into a ComboBox.

	.DESCRIPTION
		Use this function to dynamically load items into the ComboBox control.

	.PARAMETER  ComboBox
		The ComboBox control you want to add items to.

	.PARAMETER  Items
		The object or objects you wish to load into the ComboBox's Items collection.

	.PARAMETER  DisplayMember
		Indicates the property to display for the items in this control.
	
	.PARAMETER  Append
		Adds the item(s) to the ComboBox without clearing the Items collection.
	
	.EXAMPLE
		Load-ComboBox $combobox1 "Red", "White", "Blue"
	
	.EXAMPLE
		Load-ComboBox $combobox1 "Red" -Append
		Load-ComboBox $combobox1 "White" -Append
		Load-ComboBox $combobox1 "Blue" -Append
	
	.EXAMPLE
		Load-ComboBox $combobox1 (Get-Process) "ProcessName"
#>
	Param (
		[ValidateNotNull()]
		[Parameter(Mandatory=$true)]
		[System.Windows.Forms.ComboBox]$ComboBox,
		[ValidateNotNull()]
		[Parameter(Mandatory=$true)]
		$Items,
	    [Parameter(Mandatory=$false)]
		[string]$DisplayMember,
		[switch]$Append
	)
	
	if(-not $Append)
	{
		$ComboBox.Items.Clear()	
	}
	
	if($Items -is [Object[]])
	{
		$ComboBox.Items.AddRange($Items)
	}
	elseif ($Items -is [Array])
	{
		$ComboBox.BeginUpdate()
		foreach($obj in $Items)
		{
			$ComboBox.Items.Add($obj)	
		}
		$ComboBox.EndUpdate()
	}
	else
	{
		$ComboBox.Items.Add($Items)	
	}

	$ComboBox.DisplayMember = $DisplayMember	
}

function Load-DataGridView
{
	<#
	.SYNOPSIS
		This functions helps you load items into a DataGridView.

	.DESCRIPTION
		Use this function to dynamically load items into the DataGridView control.

	.PARAMETER  DataGridView
		The ComboBox control you want to add items to.

	.PARAMETER  Item
		The object or objects you wish to load into the ComboBox's items collection.
	
	.PARAMETER  DataMember
		Sets the name of the list or table in the data source for which the DataGridView is displaying data.

	#>
	Param (
		[ValidateNotNull()]
		[Parameter(Mandatory=$true)]
		[System.Windows.Forms.DataGridView]$DataGridView,
		[ValidateNotNull()]
		[Parameter(Mandatory=$true)]
		$Item,
	    [Parameter(Mandatory=$false)]
		[string]$DataMember
	)
	$DataGridView.SuspendLayout()
	$DataGridView.DataMember = $DataMember
	
	if ($Item -is [System.ComponentModel.IListSource]`
	-or $Item -is [System.ComponentModel.IBindingList] -or $Item -is [System.ComponentModel.IBindingListView] )
	{
		$DataGridView.DataSource = $Item
	}
	else
	{
		$array = New-Object System.Collections.ArrayList
		
		if ($Item -is [System.Collections.IList])
		{
			$array.AddRange($Item)
		}
		else
		{	
			$array.Add($Item)	
		}
		$DataGridView.DataSource = $array
	}
	
	$DataGridView.ResumeLayout()
}

function ConvertTo-DataTable
{
	<#
		.SYNOPSIS
			Converts objects into a DataTable.
	
		.DESCRIPTION
			Converts objects into a DataTable, which are used for DataBinding.
	
		.PARAMETER  InputObject
			The input to convert into a DataTable.
	
		.PARAMETER  Table
			The DataTable you wish to load the input into.
	
		.PARAMETER RetainColumns
			This switch tells the function to keep the DataTable's existing columns.
		
		.PARAMETER FilterWMIProperties
			This switch removes WMI properties that start with an underline.
	
		.EXAMPLE
			$DataTable = ConvertTo-DataTable -InputObject (Get-Process)
	#>
	[OutputType([System.Data.DataTable])]
	param(
	[ValidateNotNull()]
	$InputObject, 
	[ValidateNotNull()]
	[System.Data.DataTable]$Table,
	[switch]$RetainColumns,
	[switch]$FilterWMIProperties)
	
	if($Table -eq $null)
	{
		$Table = New-Object System.Data.DataTable
	}

	if($InputObject-is [System.Data.DataTable])
	{
		$Table = $InputObject
	}
	else
	{
		if(-not $RetainColumns -or $Table.Columns.Count -eq 0)
		{
			#Clear out the Table Contents
			$Table.Clear()

			if($InputObject -eq $null){ return } #Empty Data
			
			$object = $null
			#find the first non null value
			foreach($item in $InputObject)
			{
				if($item -ne $null)
				{
					$object = $item
					break	
				}
			}

			if($object -eq $null) { return } #All null then empty
			
			#Get all the properties in order to create the columns
			foreach ($prop in $object.PSObject.Get_Properties())
			{
				if(-not $FilterWMIProperties -or -not $prop.Name.StartsWith('__'))#filter out WMI properties
				{
					#Get the type from the Definition string
					$type = $null
					
					if($prop.Value -ne $null)
					{
						try{ $type = $prop.Value.GetType() } catch {}
					}

					if($type -ne $null) # -and [System.Type]::GetTypeCode($type) -ne 'Object')
					{
		      			[void]$table.Columns.Add($prop.Name, $type) 
					}
					else #Type info not found
					{ 
						[void]$table.Columns.Add($prop.Name) 	
					}
				}
		    }
			
			if($object -is [System.Data.DataRow])
			{
				foreach($item in $InputObject)
				{	
					$Table.Rows.Add($item)
				}
				return  @(,$Table)
			}
		}
		else
		{
			$Table.Rows.Clear()	
		}
		
		foreach($item in $InputObject)
		{		
			$row = $table.NewRow()
			
			if($item)
			{
				foreach ($prop in $item.PSObject.Get_Properties())
				{
					if($table.Columns.Contains($prop.Name))
					{
						$row.Item($prop.Name) = $prop.Value
					}
				}
			}
			[void]$table.Rows.Add($row)
		}
	}

	return @(,$Table)	
}
#endregion

#region Search Function
function SearchGrid()
{
	$RowIndex = 0
	$ColumnIndex = 0
	$seachString = $textboxSearch.Text
	
	if($seachString -eq "")
	{
		return
	}
	
	if($datagridviewResults.SelectedCells.Count -ne 0)
	{
		$startCell = $datagridviewResults.SelectedCells[0];
		$RowIndex = $startCell.RowIndex
		$ColumnIndex = $startCell.ColumnIndex + 1
	}
	
	$columnCount = $datagridviewResults.ColumnCount
	$rowCount = $datagridviewResults.RowCount
	for(;$RowIndex -lt $rowCount; $RowIndex++)
	{
		$Row = $datagridviewResults.Rows[$RowIndex]
		
		for(;$ColumnIndex -lt $columnCount; $ColumnIndex++)
		{
			$cell = $Row.Cells[$ColumnIndex]
			
			if($cell.Value -ne $null -and $cell.Value.ToString().IndexOf($seachString, [StringComparison]::OrdinalIgnoreCase) -ne -1)
			{
				$datagridviewResults.CurrentCell = $cell
				return
			}
		}
		
		$ColumnIndex = 0
	}
	
	$datagridviewResults.CurrentCell = $null
	[void][System.Windows.Forms.MessageBox]::Show("The search has reached the end of the grid.","String not Found")
	
}
#endregion

$formMain_Load={
	$UserCredential = Get-Credential
	$Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://outlook.office365.com/powershell-liveid/ -Credential $UserCredential -Authentication Basic -AllowRedirection
	Import-PSSession $Session -CommandName "*Quarantine*" -DisableNameChecking
}

$buttonExit_Click = {
	Get-PSSession | Remove-PSSession
	$formMain.Close()
}

$buttonRelease_Click = {
	$this.enabled = $false
	Get-QuarantineMessage -MessageId $textboxMessageId.text | Release-QuarantineMessage -ReleaseToAll
	#Add-Type -AssemblyName "System.Windows.Forms, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089"
	[void][System.Windows.Forms.MessageBox]::Show('Message released', 'Message released')
	$this.enabled = $true
}

$buttonSearch_Click={
	$this.enabled = $false
	if (!$textboxSearch.Text)
	{
		$quarantinedMessages = Get-QuarantineMessage -PageSize $numberOfItems.Value | Select-Object ReceivedTime, Type, Direction, SenderAddress, Subject, Size, Expires, MessageId
		$table = ConvertTo-DataTable -InputObject $quarantinedMessages
		Load-DataGridView -DataGridView $datagridviewResults -Item $table
	}
	else
	{
		$filter = $comboboxFilter.Text
		$quarantinedMessages = Get-QuarantineMessage -PageSize $numberOfItems.Value | Where-Object { $_.$filter -like "*" + $textboxSearch.Text + "*"} | Select-Object ReceivedTime, Type, Direction, SenderAddress, Subject, Size, Expires, MessageId
		$table = ConvertTo-DataTable -InputObject $quarantinedMessages
		Load-DataGridView -DataGridView $datagridviewResults -Item $table
	}
	$this.enabled = $true
}

$datagridviewResults_ColumnHeaderMouseClick=[System.Windows.Forms.DataGridViewCellMouseEventHandler]{
#Event Argument: $_ = [System.Windows.Forms.DataGridViewCellMouseEventArgs]
	if($datagridviewResults.DataSource -is [System.Data.DataTable])
	{
		$column = $datagridviewResults.Columns[$_.ColumnIndex]
		$direction = [System.ComponentModel.ListSortDirection]::Ascending
		
		if($column.HeaderCell.SortGlyphDirection -eq 'Descending')
		{
			$direction = [System.ComponentModel.ListSortDirection]::Descending
		}

		$datagridviewResults.Sort($datagridviewResults.Columns[$_.ColumnIndex], $direction)
	}
}

$textboxSearch_KeyDown=[System.Windows.Forms.KeyEventHandler]{
#Event Argument: $_ = [System.Windows.Forms.KeyEventArgs]
	if($_.KeyCode -eq 'Enter' -and $buttonSearch.Enabled)
	{
		SearchGrid	
		$_.SuppressKeyPress = $true
	}
}

$datagridviewResults_CellContentClick=[System.Windows.Forms.DataGridViewCellEventHandler]{
#Event Argument: $_ = [System.Windows.Forms.DataGridViewCellEventArgs]
	#TODO: Place custom script here
	
}

$textboxSearch_TextChanged={
	#TODO: Place custom script here
	
}

$comboboxFilter_SelectedIndexChanged={
	#TODO: Place custom script here
	
}