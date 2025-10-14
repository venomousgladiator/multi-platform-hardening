from fpdf import FPDF
import datetime
import os

class PDF(FPDF):
    """
    Custom PDF class to define a consistent header and footer for all pages.
    """
    def header(self):
        # Set font for the header
        self.set_font('Arial', 'B', 16)
        # Add a title cell
        self.cell(0, 10, 'SysWarden Security Compliance Report', 0, 1, 'C')
        # Line break
        self.ln(5)

    def footer(self):
        # Position cursor at 1.5 cm from the bottom
        self.set_y(-15)
        # Set font for the footer
        self.set_font('Arial', 'I', 8)
        # Add a page number
        self.cell(0, 10, f'Page {self.page_no()}/{{nb}}', 0, 0, 'C')

def generate_report(audit_results, os_type, level):
    """
    Generates a detailed PDF report from a list of audit result dictionaries.

    Args:
        audit_results (list): A list of dictionaries, where each dict represents a policy check.
        os_type (str): The operating system the audit was run on (e.g., "Windows", "Linux").
        level (str): The hardening level that was audited (e.g., "L1", "L3").

    Returns:
        str: The filename of the generated PDF report or an error message.
    """
    pdf = PDF()
    pdf.alias_nb_pages() # Enables page numbering with total pages
    pdf.add_page()
    
    # --- Report Header Section ---
    pdf.set_font('Arial', 'B', 12)
    pdf.cell(0, 10, f"Scan Details", 0, 1)
    pdf.set_font('Arial', '', 10)
    pdf.cell(0, 6, f"Operating System: {os_type}", 0, 1)
    pdf.cell(0, 6, f"Compliance Level Audited: {level}", 0, 1)
    pdf.cell(0, 6, f"Report Generated: {datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%d %H:%M:%S UTC')}", 0, 1)
    pdf.ln(10)

    # --- Executive Summary Section ---
    total_checks = len(audit_results)
    compliant = sum(1 for r in audit_results if r.get('status') == 'Compliant')
    not_compliant = sum(1 for r in audit_results if r.get('status') == 'Not Compliant')
    errors = total_checks - compliant - not_compliant
    
    pdf.set_font('Arial', 'B', 12)
    pdf.cell(0, 10, f"Executive Summary", 0, 1)
    pdf.set_font('Arial', '', 10)
    
    # Create a table for the summary
    pdf.set_fill_color(230, 230, 230) # Light gray for headers
    pdf.cell(60, 8, f"Total Policies Checked:", 1, 0, 'L', True)
    pdf.cell(0, 8, f"{total_checks}", 1, 1)
    
    pdf.set_fill_color(200, 255, 200) # Light Green
    pdf.cell(60, 8, f"Compliant:", 1, 0, 'L', True)
    pdf.cell(0, 8, f"{compliant}", 1, 1)
    
    pdf.set_fill_color(255, 200, 200) # Light Red
    pdf.cell(60, 8, f"Not Compliant:", 1, 0, 'L', True)
    pdf.cell(0, 8, f"{not_compliant}", 1, 1)
    
    pdf.set_fill_color(255, 255, 200) # Light Yellow
    pdf.cell(60, 8, f"Errors / Not Applicable:", 1, 0, 'L', True)
    pdf.cell(0, 8, f"{errors}", 1, 1)
    pdf.ln(10)
    
    # --- Detailed Findings Section ---
    pdf.set_font('Arial', 'B', 12)
    pdf.cell(0, 10, "Detailed Compliance Findings", 0, 1)

    for result in audit_results:
        # Gracefully handle potentially missing keys
        status = result.get('status', 'Error')
        parameter = result.get('parameter', 'Unknown Policy')
        details = result.get('details', 'No details were provided by the module.')

        # Determine severity and set text color for the finding
        if status == 'Compliant':
            severity = "Low"
            pdf.set_text_color(34, 139, 34) # Forest Green
        elif status == 'Not Compliant':
            severity = "High"
            pdf.set_text_color(220, 20, 60) # Crimson Red
        else: # Covers Info, Error, etc.
            severity = "Informational"
            pdf.set_text_color(0, 0, 0) # Black

        pdf.set_font('Arial', 'B', 10)
        # Use multi_cell for text that might wrap to the next line
        pdf.multi_cell(0, 6, f"Policy: {parameter}")
        
        # Reset font and color for the details
        pdf.set_font('Arial', '', 9)
        pdf.set_text_color(0, 0, 0)
        
        pdf.multi_cell(0, 5, f"  Status: {status} (Severity: {severity})")
        pdf.multi_cell(0, 5, f"  Details: {details}")
        pdf.ln(4) # Add a small break between entries

    # --- Save the PDF File ---
    # Create the 'reports' directory if it doesn't exist
    if not os.path.exists('reports'):
        os.makedirs('reports')
        
    report_name = f"reports/SysWarden_Report_{os_type}_{datetime.datetime.now().strftime('%Y%m%d_%H%M%S')}.pdf"
    
    try:
        pdf.output(report_name)
        return report_name
    except Exception as e:
        # Return a descriptive error if PDF generation fails
        return f"Error: Could not generate PDF. Reason: {e}"

